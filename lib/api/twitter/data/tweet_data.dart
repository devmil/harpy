import 'package:dart_twitter_api/twitter_api.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/core/core.dart';

part 'tweet_data.freezed.dart';

@freezed
class TweetData with _$TweetData {
  factory TweetData({
    required DateTime createdAt,
    required UserData user,

    /// The original id of this tweet.
    ///
    /// Differs from [id] when this tweet is a retweet.
    @Default('') String originalId,

    /// The id of this tweet.
    @Default('') String id,
    @Default('') String text,
    @Default('') String source,
    @Default(0) int retweetCount,
    @Default(0) int favoriteCount,
    @Default(false) bool retweeted,
    @Default(false) bool favorited,
    @Default(false) bool possiblySensitive,

    /// The BCP 47 language identifier corresponding to the machine-detected
    /// language of the Tweet text, or `und` if no language could be detected.
    @Default('und') String lang,
    @Default(EntitiesData()) EntitiesData entities,

    // optional tweet fields

    /// The id of the tweet that this tweet is replying to.
    String? parentTweetId,

    /// The user that retweeted this tweet.
    ///
    /// `null` when this tweet is not a retweet.
    UserData? retweeter,
    TweetData? quote,
    String? quoteUrl,

    // custom fields

    @Default(<TweetData>[]) List<TweetData> replies,

    /// The text of this tweet that the user can see.
    ///
    /// Does not contain optional media and quote links and the shortened urls
    /// are replaced with their display urls.
    @Default('') String visibleText,
    @Default(<MediaData>[]) List<MediaData> media,
    Translation? translation,

    /// Whether the tweet is currently being translated.
    @Default(false) bool isTranslating,
  }) = _TweetData;

  factory TweetData.fromTweet(Tweet tweet) {
    final originalId = tweet.idStr ?? '';

    UserData? retweeter;

    if (tweet.retweetedStatus != null && tweet.user != null) {
      retweeter = UserData.fromUser(tweet.user);
      tweet = tweet.retweetedStatus!;
    }

    TweetData? quote;
    String? quoteUrl;

    if (tweet.quotedStatus != null) {
      quote = TweetData.fromTweet(tweet.quotedStatus!);
      quoteUrl = tweet.quotedStatusPermalink?.url;
    }

    final mediaData = <MediaData>[];

    if (tweet.extendedEntities?.media?.isNotEmpty ?? false) {
      for (final media in tweet.extendedEntities!.media!) {
        if (media.type == kMediaPhoto) {
          mediaData.add(ImageMediaData.fromMedia(media));
        } else if (mediaData.isEmpty && media.type == kMediaVideo ||
            media.type == kMediaGif) {
          mediaData.add(VideoMediaData.fromMedia(media));
          break;
        }
      }
    }

    return TweetData(
      // required
      originalId: originalId,
      id: tweet.idStr ?? '',
      createdAt: tweet.createdAt ?? DateTime.now(),
      text: tweet.fullText ?? '',
      source: _parseSource(tweet.source),
      retweetCount: tweet.retweetCount ?? 0,
      favoriteCount: tweet.favoriteCount ?? 0,
      retweeted: tweet.retweeted ?? false,
      favorited: tweet.favorited ?? false,
      possiblySensitive: tweet.possiblySensitive ?? false,
      lang: tweet.lang ?? 'und',
      user: UserData.fromUser(tweet.user),
      entities: EntitiesData.fromEntities(tweet.entities),
      // optional
      parentTweetId: tweet.inReplyToStatusIdStr,
      retweeter: retweeter,
      quote: quote,
      quoteUrl: quoteUrl,
      // custom
      visibleText: _visibleText(tweet.fullText ?? '', quoteUrl, tweet.entities),
      media: mediaData,
    );
  }

  TweetData._();

  /// The [MediaType] for the media of this tweet or `null` if this tweet has no
  /// media.
  late final mediaType = media.isNotEmpty ? media[0].type : null;

  late final isRetweet = retweeter != null;
  late final hasImages = media.isNotEmpty && media[0].type == MediaType.image;
  late final hasSingleImage = media.length == 1 && hasImages;
  late final hasVideo = media.isNotEmpty && media[0].type == MediaType.video;
  late final hasGif = media.isNotEmpty && media[0].type == MediaType.gif;
  late final hasText = visibleText.isNotEmpty;
  late final hasParent = parentTweetId != null && parentTweetId!.isNotEmpty;
  late final tweetUrl = 'https://twitter.com/${user.handle}/status/$id';
  late final isRtlLanguage = rtlLanguageCodes.contains(lang);

  /// A concatenated string of the user names from the [replies].
  String get replyAuthors {
    final names = replies.map((reply) => reply.user.name).toSet();

    // return an empty string if the only replier is the author of this tweet
    if (setEquals(names, {user.name})) return '';

    final concatenated = names.take(5).fold<String>(
          '',
          (previousValue, name) =>
              previousValue.isNotEmpty ? '$previousValue, $name' : name,
        );

    return names.length > 5
        ? '$concatenated and ${names.length - 5} more'
        : concatenated;
  }

  bool translatable(String translateLanguage) =>
      hasText && lang != 'und' && !translateLanguage.startsWith(lang);

  bool quoteTranslatable(String translateLanguage) =>
      quote != null && quote!.translatable(translateLanguage);

  String? downloadMediaUrl([int index = 0]) {
    return media.isNotEmpty ? media[index].bestUrl : null;
  }
}

/// Returns the text that the user sees in a tweet card.
///
/// Optional media and quote links are removed and the shortened urls are
/// replaced with their display urls.
String _visibleText(String text, String? quoteUrl, Entities? entities) {
  var visibleText = text;

  // remove the quote url if it exists
  if (quoteUrl != null) visibleText = visibleText.replaceAll(quoteUrl, '');

  // remove the media url if it exists
  entities?.media?.forEach((media) {
    visibleText = visibleText.replaceAll(media.url ?? '', '');
  });

  // replace the shortened urls with the display urls
  entities?.urls?.forEach((url) {
    visibleText = visibleText.replaceAll(url.url ?? '', url.displayUrl ?? '');
  });

  return parseHtmlEntities(visibleText.trim());
}

/// Returns the source without the enclosing html tag.
String _parseSource(String? source) {
  if (source != null) {
    final match = htmlTagRegex.firstMatch(source);
    final group = match?.group(0);

    if (group != null) {
      return group;
    }
  }

  return '';
}
