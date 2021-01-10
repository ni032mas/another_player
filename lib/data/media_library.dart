import 'package:audio_service/audio_service.dart';

class MediaLibrary {
  final _items = <MediaItem>[
    MediaItem(
      id: "http://s24.myradiostream.com:14810/listen.mp3",
      album: "Radio NA",
      title: "Radio NA",
      artist: "Radio NA",
      artUri:
          "https://static.tildacdn.com/tild6634-6133-4437-b738-323539393935/Radio_NA_logo-new-ye.png",
    ),
  ];

  List<MediaItem> get items => _items;
}
