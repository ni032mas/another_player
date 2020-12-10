import 'package:another_player/tasks/audio_task.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

Stream<MediaState> get mediaStateStream => Rx.combineLatest2<MediaItem, Duration, MediaState>(
    AudioService.currentMediaItemStream, AudioService.positionStream, (mediaItem, position) => MediaState(mediaItem, position));

/// A stream reporting the combined state of the current queue and the current
/// media item within that queue.
Stream<QueueState> get queueStateStream => Rx.combineLatest2<List<MediaItem>, MediaItem, QueueState>(
    AudioService.queueStream, AudioService.currentMediaItemStream, (queue, mediaItem) => QueueState(queue, mediaItem));

Stream<PlaybackState> get playbackStateStream => AudioService.playbackStateStream.distinct(

);

Stream<AudioProcessingState> get audioProcessingStateStream => AudioService.playbackStateStream.map((state) => state.processingState).distinct();

class QueueState {
  final List<MediaItem> queue;
  final MediaItem mediaItem;

  QueueState(this.queue, this.mediaItem);
}

class MediaState {
  final MediaItem mediaItem;
  final Duration position;

  MediaState(this.mediaItem, this.position);
}

play() {
  if (AudioService.running) {
    AudioService.play();
  } else {
    AudioService.start(
      backgroundTaskEntrypoint: audioPlayerTaskEntrypoint,
      androidNotificationChannelName: 'Audio Service Demo',
      // Enable this if you want the Android service to exit the foreground state on pause.
      //androidStopForegroundOnPause: true,
      androidNotificationColor: 0xFF2196f3,
      androidNotificationIcon: 'mipmap/ic_launcher',
      androidEnableQueue: true,
    );
  }
}

stopAudioService() {
  AudioService.stop();
}

pause() {
  AudioService.pause();
}

seekTo(Duration position) {
  AudioService.seekTo(position);
}

seekBackward() {
  AudioService.seekBackward(true);
}

seekForward() {
  AudioService.seekForward(true);
}

setVolume(double volume) {
  AudioService.customAction(SET_VOLUME, volume);
}

setSpeed(double speed) {
  AudioService.customAction(SET_SPEED, speed);
}

const SET_VOLUME = "setVolume";
const SET_SPEED = "setSpeed";
