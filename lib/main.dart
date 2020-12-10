import 'dart:async';
import 'dart:io';

import 'package:another_player/tasks/audio_task.dart';
import 'package:another_player/widgets/control_button.dart';
import 'package:another_player/widgets/seek_bar.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';

import 'data/audio_service.dart';

void main() => runApp(
      MultiProvider(
        providers: [
          StreamProvider<bool>.value(value: AudioService.runningStream),
          StreamProvider<QueueState>.value(value: queueStateStream),
          StreamProvider<MediaState>.value(value: mediaStateStream),
          StreamProvider<PlaybackState>.value(value: playbackStateStream),
          StreamProvider<VolumeState>.value(
            value: AudioService.customEventStream.map((event) => event),
          ),
          StreamProvider<SpeedState>.value(
            value: AudioService.customEventStream.map((event) => event),
          ),
        ],
        child: new AnotherPlayer(),
      ),
    );

class AnotherPlayer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Audio Service Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: AudioServiceWidget(child: MainScreen()),
    );
  }
}

class MainScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Another player'),
      ),
      body: Center(
        child: Consumer<bool>(
          builder: (context, model, widget) {
            final running = model ?? false;
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Consumer<QueueState>(
                  builder: (context, queueState, widget) {
                    final queue = queueState?.queue ?? [];
                    final mediaItem = queueState?.mediaItem;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (queue != null && queue.isNotEmpty)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: Icon(Icons.skip_previous),
                                iconSize: 64.0,
                                onPressed: mediaItem == queue.first
                                    ? null
                                    : AudioService.skipToPrevious,
                              ),
                              IconButton(
                                icon: Icon(Icons.skip_next),
                                iconSize: 64.0,
                                onPressed: mediaItem == queue.last
                                    ? null
                                    : AudioService.skipToNext,
                              ),
                            ],
                          ),
                        if (mediaItem?.title != null) Text(mediaItem.title),
                      ],
                    );
                  },
                ),
                ControlButtons(),
                Consumer<MediaState>(
                  builder: (context, mediaState, widget) {
                    return SeekBar(
                      duration:
                          mediaState?.mediaItem?.duration ?? Duration.zero,
                      position: mediaState?.position ?? Duration.zero,
                      onChangeEnd: (newPosition) {
                        AudioService.seekTo(newPosition);
                      },
                    );
                  },
                ),
                StreamBuilder<AudioProcessingState>(
                  stream: audioProcessingStateStream,
                  builder: (context, snapshot) {
                    final processingState =
                        snapshot.data ?? AudioProcessingState.none;
                    return Text(
                        "Processing state: ${describeEnum(processingState)}");
                  },
                ),
                StreamBuilder(
                  stream: AudioService.customEventStream,
                  builder: (context, snapshot) {
                    return Text("custom event: ${snapshot.data}");
                  },
                ),
                StreamBuilder<bool>(
                  stream: AudioService.notificationClickEventStream,
                  builder: (context, snapshot) {
                    return Text(
                      'Notification Click Status: ${snapshot.data}',
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// A stream reporting the combined state of the current media item and its
  /// current position.

  RaisedButton audioPlayerButton() => startButton(
        'AudioPlayer',
        () {
          AudioService.start(
            backgroundTaskEntrypoint: audioPlayerTaskEntrypoint,
            androidNotificationChannelName: 'Audio Service Demo',
            // Enable this if you want the Android service to exit the foreground state on pause.
            //androidStopForegroundOnPause: true,
            androidNotificationColor: 0xFF2196f3,
            androidNotificationIcon: 'mipmap/ic_launcher',
            androidEnableQueue: true,
          );
        },
      );

  RaisedButton textToSpeechButton() => startButton(
        'TextToSpeech',
        () {
          AudioService.start(
            backgroundTaskEntrypoint: _textToSpeechTaskEntrypoint,
            androidNotificationChannelName: 'Audio Service Demo',
            androidNotificationColor: 0xFF2196f3,
            androidNotificationIcon: 'mipmap/ic_launcher',
          );
        },
      );

  RaisedButton startButton(String label, VoidCallback onPressed) =>
      RaisedButton(
        child: Text(label),
        onPressed: onPressed,
      );

  IconButton playButton() => IconButton(
        icon: Icon(Icons.play_arrow),
        iconSize: 64.0,
        onPressed: AudioService.play,
      );

  IconButton pauseButton() => IconButton(
        icon: Icon(Icons.pause),
        iconSize: 64.0,
        onPressed: AudioService.pause,
      );

  IconButton stopButton() => IconButton(
        icon: Icon(Icons.stop),
        iconSize: 64.0,
        onPressed: AudioService.stop,
      );
}

/// This task defines logic for playing a list of podcast episodes.

/// Provides access to a library of media items. In your app, this could come
/// from a database or web service.

// NOTE: Your entrypoint MUST be a top-level function.
void _textToSpeechTaskEntrypoint() async {
  AudioServiceBackground.run(() => TextPlayerTask());
}

/// This task defines logic for speaking a sequence of numbers using
/// text-to-speech.
class TextPlayerTask extends BackgroundAudioTask {
  Tts _tts = Tts();
  bool _finished = false;
  Sleeper _sleeper = Sleeper();
  Completer _completer = Completer();
  bool _interrupted = false;

  bool get _playing => AudioServiceBackground.state.playing;

  @override
  Future<void> onStart(Map<String, dynamic> params) async {
    // flutter_tts resets the AVAudioSession category to playAndRecord and the
    // options to defaultToSpeaker whenever this background isolate is loaded,
    // so we need to set our preferred audio session configuration here after
    // that has happened.
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration.speech());
    // Handle audio interruptions.
    session.interruptionEventStream.listen((event) {
      if (event.begin) {
        if (_playing) {
          onPause();
          _interrupted = true;
        }
      } else {
        switch (event.type) {
          case AudioInterruptionType.pause:
          case AudioInterruptionType.duck:
            if (!_playing && _interrupted) {
              onPlay();
            }
            break;
          case AudioInterruptionType.unknown:
            break;
        }
        _interrupted = false;
      }
    });
    // Handle unplugged headphones.
    session.becomingNoisyEventStream.listen((_) {
      if (_playing) onPause();
    });

    // Start playing.
    await _playPause();
    for (var i = 1; i <= 10 && !_finished;) {
      AudioServiceBackground.setMediaItem(mediaItem(i));
      AudioServiceBackground.androidForceEnableMediaButtons();
      try {
        await _tts.speak('$i');
        i++;
        await _sleeper.sleep(Duration(milliseconds: 300));
      } catch (e) {
        // Speech was interrupted
      }
      // If we were just paused
      if (!_finished && !_playing) {
        try {
          // Wait to be unpaused
          await _sleeper.sleep();
        } catch (e) {
          // unpaused
        }
      }
    }
    await AudioServiceBackground.setState(
      controls: [],
      processingState: AudioProcessingState.stopped,
      playing: false,
    );
    if (!_finished) {
      onStop();
    }
    _completer.complete();
  }

  @override
  Future<void> onPlay() => _playPause();

  @override
  Future<void> onPause() => _playPause();

  @override
  Future<void> onStop() async {
    // Signal the speech to stop
    _finished = true;
    _sleeper.interrupt();
    _tts.interrupt();
    // Wait for the speech to stop
    await _completer.future;
    // Shut down this task
    await super.onStop();
  }

  MediaItem mediaItem(int number) => MediaItem(
      id: 'tts_$number',
      album: 'Numbers',
      title: 'Number $number',
      artist: 'Sample Artist');

  Future<void> _playPause() async {
    if (_playing) {
      _interrupted = false;
      await AudioServiceBackground.setState(
        controls: [MediaControl.play, MediaControl.stop],
        processingState: AudioProcessingState.ready,
        playing: false,
      );
      _sleeper.interrupt();
      _tts.interrupt();
    } else {
      final session = await AudioSession.instance;
      // flutter_tts doesn't activate the session, so we do it here. This
      // allows the app to stop other apps from playing audio while we are
      // playing audio.
      if (await session.setActive(true)) {
        // If we successfully activated the session, set the state to playing
        // and resume playback.
        await AudioServiceBackground.setState(
          controls: [MediaControl.pause, MediaControl.stop],
          processingState: AudioProcessingState.ready,
          playing: true,
        );
        _sleeper.interrupt();
      }
    }
  }
}

/// An object that performs interruptable sleep.
class Sleeper {
  Completer _blockingCompleter;

  /// Sleep for a duration. If sleep is interrupted, a
  /// [SleeperInterruptedException] will be thrown.
  Future<void> sleep([Duration duration]) async {
    _blockingCompleter = Completer();
    if (duration != null) {
      await Future.any([Future.delayed(duration), _blockingCompleter.future]);
    } else {
      await _blockingCompleter.future;
    }
    final interrupted = _blockingCompleter.isCompleted;
    _blockingCompleter = null;
    if (interrupted) {
      throw SleeperInterruptedException();
    }
  }

  /// Interrupt any sleep that's underway.
  void interrupt() {
    if (_blockingCompleter?.isCompleted == false) {
      _blockingCompleter.complete();
    }
  }
}

class SleeperInterruptedException {}

/// A wrapper around FlutterTts that makes it easier to wait for speech to
/// complete.
class Tts {
  final FlutterTts _flutterTts = new FlutterTts();
  Completer _speechCompleter;
  bool _interruptRequested = false;
  bool _playing = false;

  Tts() {
    _flutterTts.setCompletionHandler(() {
      _speechCompleter?.complete();
    });
  }

  bool get playing => _playing;

  Future<void> speak(String text) async {
    _playing = true;
    if (!_interruptRequested) {
      _speechCompleter = Completer();
      await _flutterTts.speak(text);
      await _speechCompleter.future;
      _speechCompleter = null;
    }
    _playing = false;
    if (_interruptRequested) {
      _interruptRequested = false;
      throw TtsInterruptedException();
    }
  }

  Future<void> stop() async {
    if (_playing) {
      await _flutterTts.stop();
      _speechCompleter?.complete();
    }
  }

  void interrupt() {
    if (_playing) {
      _interruptRequested = true;
      stop();
    }
  }
}

class TtsInterruptedException {}
