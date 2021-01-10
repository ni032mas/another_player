import 'package:another_player/data/audio_service.dart';
import 'package:another_player/tasks/audio_task.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ControlButtons extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<QueueState>(
      builder: (context, queueState, widget) {
        final queue = queueState?.queue;
        final mediaItem = queueState?.mediaItem;
        return Column(
          children: [
            Container(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: mediaItem != null
                    ? Center(
                        child: ColorFiltered(
                          child: Image.network(mediaItem.artUri),
                          colorFilter:
                              ColorFilter.mode(Colors.red, BlendMode.modulate),
                        ),
                      )
                    : Container(),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.volume_up),
                  onPressed: () {
                    _showSliderDialogVolume(
                      context: context,
                      title: "Adjust volume",
                      divisions: 10,
                      min: 0.0,
                      max: 1.0,
                      onChanged: setVolume,
                    );
                  },
                ),
                IconButton(
                  icon: Icon(Icons.skip_previous),
                  iconSize: 64.0,
                  onPressed:
                      (queue?.isEmpty ?? true) || mediaItem == queue?.first
                          ? null
                          : AudioService.skipToPrevious,
                ),
                PlaybackButton(),
                IconButton(
                  icon: Icon(Icons.skip_next),
                  iconSize: 64.0,
                  onPressed:
                      (queue?.isEmpty ?? true) || mediaItem == queue?.last
                          ? null
                          : AudioService.skipToNext,
                ),
                IconButton(
                  icon: Consumer<SpeedState>(
                    builder: (context, model, widget) => Container(
                      height: 100.0,
                      child: Text("${model?.speed?.toStringAsFixed(1) ?? 1.0}x",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  onPressed: () {
                    _showSliderDialogSpeed(
                      context: context,
                      title: "Adjust speed",
                      divisions: 10,
                      min: 0.5,
                      max: 1.5,
                      onChanged: setSpeed,
                    );
                  },
                )
              ],
            ),
          ],
        );
      },
    );
  }
}

class PlaybackButton extends StatefulWidget {
  @override
  _PlaybackButtonState createState() => _PlaybackButtonState();
}

class _PlaybackButtonState extends State<PlaybackButton> {
  @override
  Widget build(BuildContext context) {
    return Consumer<PlaybackState>(builder: (context, playbackState, child) {
      if (playbackState?.processingState == AudioProcessingState.connecting ||
          playbackState?.processingState == AudioProcessingState.buffering) {
        return Container(
          margin: EdgeInsets.all(8.0),
          width: 64.0,
          height: 64.0,
          child: CircularProgressIndicator(),
        );
      } else if (playbackState == null ||
          !(playbackState?.playing ?? true) ||
          playbackState?.processingState == AudioProcessingState.none) {
        return IconButton(
          icon: Icon(Icons.play_arrow),
          iconSize: 64.0,
          onPressed: play,
        );
      } else if (playbackState?.processingState !=
          AudioProcessingState.completed) {
        return IconButton(
          icon: Icon(Icons.pause),
          iconSize: 64.0,
          onPressed: pause,
        );
      } else {
        return IconButton(
          icon: Icon(Icons.replay),
          iconSize: 64.0,
          onPressed: () => seekTo(Duration.zero),
        );
      }
    });
  }
}

_showSliderDialogVolume({
  BuildContext context,
  String title,
  int divisions,
  double min,
  double max,
  String valueSuffix = '',
  ValueChanged<double> onChanged,
}) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title, textAlign: TextAlign.center),
      content: Consumer<VolumeState>(
        builder: (context, model, widget) => Container(
          height: 100.0,
          child: Column(
            children: [
              Text('${model?.volume?.toStringAsFixed(1) ?? 1}$valueSuffix',
                  style: TextStyle(
                      fontFamily: 'Fixed',
                      fontWeight: FontWeight.bold,
                      fontSize: 24.0)),
              Slider(
                divisions: divisions,
                min: min,
                max: max,
                value: model?.volume ?? 1.0,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

_showSliderDialogSpeed({
  BuildContext context,
  String title,
  int divisions,
  double min,
  double max,
  String valueSuffix = '',
  ValueChanged<double> onChanged,
}) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title, textAlign: TextAlign.center),
      content: Consumer<SpeedState>(
        builder: (context, model, widget) => Container(
          height: 100.0,
          child: Column(
            children: [
              Text('${model?.speed?.toStringAsFixed(1) ?? 1}$valueSuffix',
                  style: TextStyle(
                      fontFamily: 'Fixed',
                      fontWeight: FontWeight.bold,
                      fontSize: 24.0)),
              Slider(
                divisions: divisions,
                min: min,
                max: max,
                value: model?.speed ?? 1.0,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
