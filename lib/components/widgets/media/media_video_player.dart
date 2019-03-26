import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:harpy/components/widgets/media/media_player.dart';
import 'package:harpy/components/widgets/shared/animations.dart';
import 'package:harpy/components/widgets/shared/buttons.dart';
import 'package:harpy/models/media_model.dart';
import 'package:video_player/video_player.dart';

/// The display icon size for the media video player and overlay.
const double kMediaIconSize = 64.0;

/// The [VideoPlayer] for twitter videos.
///
/// A [MediaVideoOverlay] is built on the [VideoPlayer] to allow for controlling
/// the [VideoPlayer].
///
/// Depending on the media settings it will autoplay or display the thumbnail
/// and initialize the video on tap.
class MediaVideoPlayer extends StatefulWidget {
  const MediaVideoPlayer({
    @required this.mediaModel,
  });

  final MediaModel mediaModel;

  @override
  MediaVideoPlayerState createState() => MediaVideoPlayerState();
}

class MediaVideoPlayerState extends State<MediaVideoPlayer>
    with MediaPlayerMixin<MediaVideoPlayer> {
  bool fullscreen = false;

  @override
  MediaModel get mediaModel => widget.mediaModel;

  Future<void> pushFullscreen() async {
    SystemChrome.setEnabledSystemUIOverlays([]);

    if (mediaModel.getVideoAspectRatio() > 1) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }

    fullscreen = true;

    await Navigator.of(context).push(PageRouteBuilder(
      settings: RouteSettings(isInitialRoute: false),
      pageBuilder: _buildFullscreen,
    ));

    fullscreen = false;

    SystemChrome.setEnabledSystemUIOverlays(SystemUiOverlay.values);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  Widget buildThumbnail() {
    return Stack(
      children: <Widget>[
        CachedNetworkImage(
          fit: BoxFit.cover,
          imageUrl: mediaModel.getThumbnailUrl(),
          height: double.infinity,
          width: double.infinity,
        ),
        Center(
          child: initializing
              ? CircularProgressIndicator()
              : CircleButton(
                  child: Icon(Icons.play_arrow, size: kMediaIconSize),
                ),
        ),
      ],
    );
  }

  /// Builds the video player with a [MediaVideoOverlay].
  @override
  Widget buildVideoPlayer() {
    return MediaVideoOverlay(
      videoPlayer: this,
      child: Container(
        color: Colors.black,
        child: OverflowBox(
          maxHeight: double.infinity,
          child: AspectRatio(
            aspectRatio: mediaModel.getVideoAspectRatio(),
            child: VideoPlayer(controller),
          ),
        ),
      ),
    );
  }

  /// Builds the video player in fullscreen.
  Widget _buildFullscreen(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Scaffold(
          body: Container(
            color: Colors.black,
            alignment: Alignment.center,
            child: build(context),
          ),
        );
      },
    );
  }
}

/// The overlay for a [MediaVideoPlayer].
///
/// Shows the actions for the video (play, pause, fullscreen, etc.) and the
/// progress indicator.
///
/// Automatically hides after a set amount of time when the video is playing.
class MediaVideoOverlay extends StatefulWidget {
  const MediaVideoOverlay({
    @required this.videoPlayer,
    @required this.child,
  });

  final MediaVideoPlayerState videoPlayer;
  final Widget child;

  @override
  _MediaVideoOverlayState createState() => _MediaVideoOverlayState();
}

class _MediaVideoOverlayState extends State<MediaVideoOverlay>
    with
        MediaOverlayMixin<MediaVideoOverlay>,
        TickerProviderStateMixin<MediaVideoOverlay> {
  /// Handles the visibility of the overlay.
  AnimationController _visibilityController;

  /// Whether or not the overlay for the video player should be drawn.
  bool get _overlayShowing => !_visibilityController.isCompleted || finished;

  /// `true` when showing the overlay after it was hidden to determine whether
  /// or not to show the play icon widget.
  bool _reshowingOverlay = false;

  @override
  void initState() {
    super.initState();

    controller = widget.videoPlayer.controller;
    controller.addListener(listener);

    _visibilityController = new AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          // rebuild when controller completed to hide overlay
          setState(() {});
        }
      })
      ..forward();
  }

  @override
  void dispose() {
    _visibilityController.dispose();

    super.dispose();
  }

  /// Shows the overlay if it is currently hidden or plays / pauses the video
  /// if the overlay is already showing.
  void _onVideoTap() {
    if (_overlayShowing) {
      _reshowingOverlay = false;

      if (finished) {
        // replay
        setState(() {
          controller.seekTo(Duration.zero);
        });
      } else {
        _togglePlay();
      }
    } else {
      // show overlay
      setState(() {
        _visibilityController.reset();
        _visibilityController.forward();
        _reshowingOverlay = true;
      });
    }
  }

  void _togglePlay() {
    if (playing) {
      // pause
      setState(() {
        playing = false;
        controller.pause();
        _visibilityController.reset();
      });
    } else {
      // play
      setState(() {
        playing = true;
        controller.play();
        _visibilityController.forward();
      });
    }
  }

  void _onFullscreenTap() {
    if (widget.videoPlayer.fullscreen) {
      Navigator.of(context).maybePop();
    } else {
      controller.removeListener(listener);
      widget.videoPlayer.pushFullscreen();
    }
  }

  /// Builds the widget in the center of the overlay.
  Widget _buildCenterIcon() {
    if (buffering) {
      return Center(child: CircularProgressIndicator());
    }

    if (!_overlayShowing) {
      return Container();
    }

    Widget centerWidget;

    if (finished) {
      centerWidget = Icon(Icons.replay, size: kMediaIconSize);
    } else if (playing) {
      centerWidget = _reshowingOverlay
          ? Container()
          : FadeOutWidget(
              child: CircleButton(
                child: Icon(Icons.play_arrow, size: kMediaIconSize),
              ),
            );
    } else {
      centerWidget = FadeOutWidget(
        child: CircleButton(
          child: Icon(Icons.pause, size: kMediaIconSize),
        ),
      );
    }

    return Center(child: centerWidget);
  }

  /// Builds the bottom controls of the overlay.
  Widget _buildBottomRow() {
    return AnimatedOpacity(
      key: Key(widget.videoPlayer.controller.dataSource),
      opacity: _overlayShowing ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          // button row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              // play / pause button
              CircleButton(
                child: Icon(playing ? Icons.pause : Icons.play_arrow),
                onPressed: _togglePlay,
              ),

              Spacer(),

              // fullscreen button
              CircleButton(
                child: Icon(widget.videoPlayer.fullscreen
                    ? Icons.fullscreen_exit
                    : Icons.fullscreen),
                onPressed: _onFullscreenTap,
              ),
            ],
          ),

          // progress indicator
          VideoProgressIndicator(
            controller,
            padding: EdgeInsets.zero,
            allowScrubbing: true,
            colors: VideoProgressColors(
              playedColor: Theme.of(context).accentColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onVideoTap,
      child: Stack(children: <Widget>[
        widget.child,
        _buildBottomRow(),
        _buildCenterIcon(),
      ]),
    );
  }
}
