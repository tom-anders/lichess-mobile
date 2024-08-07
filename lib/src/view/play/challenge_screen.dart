import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/model/account/account_repository.dart';
import 'package:lichess_mobile/src/model/challenge/challenge.dart';
import 'package:lichess_mobile/src/model/challenge/challenge_preferences.dart';
import 'package:lichess_mobile/src/model/common/chess.dart';
import 'package:lichess_mobile/src/model/lobby/game_setup.dart';
import 'package:lichess_mobile/src/model/user/user.dart';
import 'package:lichess_mobile/src/styles/styles.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/utils/navigation.dart';
import 'package:lichess_mobile/src/view/game/game_screen.dart';
import 'package:lichess_mobile/src/widgets/adaptive_choice_picker.dart';
import 'package:lichess_mobile/src/widgets/buttons.dart';
import 'package:lichess_mobile/src/widgets/expanded_section.dart';
import 'package:lichess_mobile/src/widgets/feedback.dart';
import 'package:lichess_mobile/src/widgets/list.dart';
import 'package:lichess_mobile/src/widgets/non_linear_slider.dart';
import 'package:lichess_mobile/src/widgets/platform.dart';

class ChallengeScreen extends StatelessWidget {
  const ChallengeScreen(this.user);

  final LightUser user;

  @override
  Widget build(BuildContext context) {
    return PlatformWidget(androidBuilder: _buildAndroid, iosBuilder: _buildIos);
  }

  Widget _buildIos(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(),
      child: _ChallengeBody(user),
    );
  }

  Widget _buildAndroid(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.challengeChallengesX(user.name))),
      body: _ChallengeBody(user),
    );
  }
}

class _ChallengeBody extends ConsumerStatefulWidget {
  const _ChallengeBody(this.user);

  final LightUser user;

  @override
  ConsumerState<_ChallengeBody> createState() => _ChallengeBodyState();
}

class _ChallengeBodyState extends ConsumerState<_ChallengeBody> {
  Future<void>? _pendingCreateGame;

  @override
  Widget build(BuildContext context) {
    final accountAsync = ref.watch(accountProvider);
    final preferences = ref.watch(challengePreferencesProvider);
    final isValidTimeControl =
        preferences.timeControl != ChallengeTimeControlType.clock ||
            preferences.clock.time > Duration.zero ||
            preferences.clock.increment >= Duration.zero;

    return accountAsync.when(
      data: (account) {
        final timeControl = preferences.timeControl;

        return Center(
          child: ListView(
            shrinkWrap: true,
            padding: Theme.of(context).platform == TargetPlatform.iOS
                ? Styles.sectionBottomPadding
                : Styles.verticalBodyPadding,
            children: [
              PlatformListTile(
                harmonizeCupertinoTitleStyle: true,
                title: Text(context.l10n.timeControl),
                trailing: AdaptiveTextButton(
                  onPressed: () {
                    showChoicePicker(
                      context,
                      choices: [
                        ChallengeTimeControlType.clock,
                        ChallengeTimeControlType.correspondence,
                        ChallengeTimeControlType.unlimited,
                      ],
                      selectedItem: preferences.timeControl,
                      labelBuilder: (ChallengeTimeControlType timeControl) =>
                          Text(
                        timeControl == ChallengeTimeControlType.clock
                            ? context.l10n.realTime
                            : timeControl ==
                                    ChallengeTimeControlType.correspondence
                                ? context.l10n.correspondence
                                : context.l10n.unlimited,
                      ),
                      onSelectedItemChanged: (ChallengeTimeControlType value) {
                        ref
                            .read(challengePreferencesProvider.notifier)
                            .setTimeControl(value);
                      },
                    );
                  },
                  child: Text(
                    preferences.timeControl == ChallengeTimeControlType.clock
                        ? context.l10n.realTime
                        : context.l10n.correspondence,
                  ),
                ),
              ),
              if (timeControl == ChallengeTimeControlType.clock) ...[
                Builder(
                  builder: (context) {
                    int seconds = preferences.clock.time.inSeconds;
                    return StatefulBuilder(
                      builder: (context, setState) {
                        return PlatformListTile(
                          harmonizeCupertinoTitleStyle: true,
                          title: Text.rich(
                            TextSpan(
                              text: '${context.l10n.minutesPerSide}: ',
                              children: [
                                TextSpan(
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                  text: _clockTimeLabel(seconds),
                                ),
                              ],
                            ),
                          ),
                          subtitle: NonLinearSlider(
                            value: seconds,
                            values: kAvailableTimesInSeconds,
                            labelBuilder: _clockTimeLabel,
                            onChange:
                                Theme.of(context).platform == TargetPlatform.iOS
                                    ? (num value) {
                                        setState(() {
                                          seconds = value.toInt();
                                        });
                                      }
                                    : null,
                            onChangeEnd: (num value) {
                              setState(() {
                                seconds = value.toInt();
                              });
                              ref
                                  .read(challengePreferencesProvider.notifier)
                                  .setClock(
                                    Duration(seconds: value.toInt()),
                                    preferences.clock.increment,
                                  );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
                Builder(
                  builder: (context) {
                    int incrementSeconds =
                        preferences.clock.increment.inSeconds;
                    return StatefulBuilder(
                      builder: (context, setState) {
                        return PlatformListTile(
                          harmonizeCupertinoTitleStyle: true,
                          title: Text.rich(
                            TextSpan(
                              text: '${context.l10n.incrementInSeconds}: ',
                              children: [
                                TextSpan(
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                  text: incrementSeconds.toString(),
                                ),
                              ],
                            ),
                          ),
                          subtitle: NonLinearSlider(
                            value: incrementSeconds,
                            values: kAvailableIncrementsInSeconds,
                            onChange:
                                Theme.of(context).platform == TargetPlatform.iOS
                                    ? (num value) {
                                        setState(() {
                                          incrementSeconds = value.toInt();
                                        });
                                      }
                                    : null,
                            onChangeEnd: (num value) {
                              setState(() {
                                incrementSeconds = value.toInt();
                              });
                              ref
                                  .read(challengePreferencesProvider.notifier)
                                  .setClock(
                                    preferences.clock.time,
                                    Duration(seconds: value.toInt()),
                                  );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ] else ...[
                Builder(
                  builder: (context) {
                    int daysPerTurn = preferences.days;
                    return StatefulBuilder(
                      builder: (context, setState) {
                        return PlatformListTile(
                          harmonizeCupertinoTitleStyle: true,
                          title: Text.rich(
                            TextSpan(
                              text: '${context.l10n.daysPerTurn}: ',
                              children: [
                                TextSpan(
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                  text: _daysLabel(daysPerTurn),
                                ),
                              ],
                            ),
                          ),
                          subtitle: NonLinearSlider(
                            value: daysPerTurn,
                            values: kAvailableDaysPerTurn,
                            labelBuilder: _daysLabel,
                            onChange:
                                Theme.of(context).platform == TargetPlatform.iOS
                                    ? (num value) {
                                        setState(() {
                                          daysPerTurn = value.toInt();
                                        });
                                      }
                                    : null,
                            onChangeEnd: (num value) {
                              setState(() {
                                daysPerTurn = value.toInt();
                              });
                              ref
                                  .read(challengePreferencesProvider.notifier)
                                  .setDays(value.toInt());
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
              PlatformListTile(
                harmonizeCupertinoTitleStyle: true,
                title: Text(context.l10n.variant),
                trailing: AdaptiveTextButton(
                  onPressed: () {
                    showChoicePicker(
                      context,
                      choices: [Variant.standard, Variant.chess960],
                      selectedItem: preferences.variant,
                      labelBuilder: (Variant variant) => Text(variant.label),
                      onSelectedItemChanged: (Variant variant) {
                        ref
                            .read(challengePreferencesProvider.notifier)
                            .setVariant(variant);
                      },
                    );
                  },
                  child: Text(preferences.variant.label),
                ),
              ),
              ExpandedSection(
                expand: preferences.rated == false,
                child: PlatformListTile(
                  harmonizeCupertinoTitleStyle: true,
                  title: Text(context.l10n.side),
                  trailing: AdaptiveTextButton(
                    onPressed: () {
                      showChoicePicker<SideChoice>(
                        context,
                        choices: SideChoice.values,
                        selectedItem: preferences.sideChoice,
                        labelBuilder: (SideChoice side) =>
                            Text(_customSideLabel(context, side)),
                        onSelectedItemChanged: (SideChoice side) {
                          ref
                              .read(challengePreferencesProvider.notifier)
                              .setSideChoice(side);
                        },
                      );
                    },
                    child: Text(
                      _customSideLabel(context, preferences.sideChoice),
                    ),
                  ),
                ),
              ),
              if (account != null)
                PlatformListTile(
                  harmonizeCupertinoTitleStyle: true,
                  title: Text(context.l10n.rated),
                  trailing: Switch.adaptive(
                    applyCupertinoTheme: true,
                    value: preferences.rated,
                    onChanged: (bool value) {
                      ref
                          .read(challengePreferencesProvider.notifier)
                          .setRated(value);
                    },
                  ),
                ),
              const SizedBox(height: 20),
              FutureBuilder(
                future: _pendingCreateGame,
                builder: (context, snapshot) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: FatButton(
                      semanticsLabel: context.l10n.challengeChallengeToPlay,
                      onPressed: timeControl == ChallengeTimeControlType.clock
                          ? isValidTimeControl
                              ? () {
                                  pushPlatformRoute(
                                    context,
                                    rootNavigator: true,
                                    builder: (BuildContext context) {
                                      return GameScreen(
                                        challenge: preferences
                                            .makeRequest(widget.user),
                                      );
                                    },
                                  );
                                }
                              : null
                          : snapshot.connectionState == ConnectionState.waiting
                              ? null
                              // TODO handle correspondence time control
                              : () async {
                                  showPlatformSnackbar(
                                    context,
                                    'Correspondence time control is not supported yet',
                                  );
                                },
                      child: Text(
                        context.l10n.challengeChallengeToPlay,
                        style: Styles.bold,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
      error: (error, stackTrace) => Center(
        child: Text(context.l10n.mobileCouldNotLoadAccountData),
      ),
    );
  }
}

String _daysLabel(num days) {
  return days == -1 ? '∞' : days.toString();
}

String _customSideLabel(BuildContext context, SideChoice side) {
  switch (side) {
    case SideChoice.white:
      return context.l10n.white;
    case SideChoice.black:
      return context.l10n.black;
    case SideChoice.random:
      return context.l10n.randomColor;
  }
}

String _clockTimeLabel(num seconds) {
  switch (seconds) {
    case 0:
      return '0';
    case 45:
      return '¾';
    case 30:
      return '½';
    case 15:
      return '¼';
    default:
      return (seconds / 60).toString().replaceAll('.0', '');
  }
}
