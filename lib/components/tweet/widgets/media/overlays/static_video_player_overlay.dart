import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/core/core.dart';
import 'package:harpy/rby/rby.dart';

class StaticVideoPlayerOverlay extends ConsumerWidget {
  const StaticVideoPlayerOverlay({
    required this.child,
    required this.data,
    required this.notifier,
  });

  final Widget child;
  final VideoPlayerStateData data;
  final VideoPlayerNotifier notifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      // eat all tap gestures that are not handled otherwise (e.g. tapping on
      // the overlay)
      onTap: () {},
      child: Stack(
        alignment: Alignment.center,
        children: [
          GestureDetector(
            onTap: notifier.togglePlayback,
            child: child,
          ),
          VideoPlayerDoubleTapActions(
            notifier: notifier,
            data: data,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                VideoPlayerProgressIndicator(notifier: notifier),
                VideoPlayerActions(
                  notifier: notifier,
                  data: data,
                  children: [
                    smallHorizontalSpacer,
                    VideoPlayerPlaybackButton(data: data, notifier: notifier),
                    VideoPlayerMuteButton(data: data, notifier: notifier),
                    smallHorizontalSpacer,
                    VideoPlayerProgressText(data: data),
                    const Spacer(),
                    if (data.qualities.length > 1)
                      VideoPlayerQualityButton(data: data, notifier: notifier),
                    const VideoPlayerFullscreenButton(),
                    smallHorizontalSpacer,
                  ],
                ),
              ],
            ),
          ),
          if (data.isBuffering)
            const ImmediateOpacityAnimation(
              delay: Duration(milliseconds: 500),
              duration: kLongAnimationDuration,
              child: MediaThumbnailIcon(icon: CircularProgressIndicator()),
            )
          else if (data.isFinished)
            const ImmediateOpacityAnimation(
              duration: kLongAnimationDuration,
              child: MediaThumbnailIcon(
                icon: Icon(Icons.replay),
              ),
            ),
          if (data.isPlaying)
            AnimatedMediaThumbnailIcon(
              key: ValueKey(data.isPlaying),
              icon: const Icon(Icons.play_arrow_rounded),
            )
          else
            AnimatedMediaThumbnailIcon(
              key: ValueKey(data.isPlaying),
              icon: const Icon(Icons.pause_rounded),
            ),
        ],
      ),
    );
  }
}
