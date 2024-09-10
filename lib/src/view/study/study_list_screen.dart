import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/model/auth/auth_session.dart';
import 'package:lichess_mobile/src/model/common/http.dart';
import 'package:lichess_mobile/src/model/study/study.dart';
import 'package:lichess_mobile/src/model/study/study_filter.dart';
import 'package:lichess_mobile/src/model/study/study_list_paginator.dart';
import 'package:lichess_mobile/src/model/study/study_repository.dart';
import 'package:lichess_mobile/src/styles/lichess_icons.dart';
import 'package:lichess_mobile/src/styles/styles.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/utils/lichess_assets.dart';
import 'package:lichess_mobile/src/widgets/adaptive_bottom_sheet.dart';
import 'package:lichess_mobile/src/widgets/buttons.dart';
import 'package:lichess_mobile/src/widgets/filter.dart';
import 'package:lichess_mobile/src/widgets/list.dart';
import 'package:lichess_mobile/src/widgets/platform_scaffold.dart';
import 'package:lichess_mobile/src/widgets/user_full_name.dart';
import 'package:logging/logging.dart';
import 'package:timeago/timeago.dart' as timeago;

final _logger = Logger('StudyListScreen');

// TODO l10n
String studyCategoryL10n(StudyCategory category, BuildContext context) =>
    switch (category) {
      StudyCategory.all => 'All',
      StudyCategory.mine => 'Mine',
      StudyCategory.member => 'Member',
      StudyCategory.public => 'Public',
      StudyCategory.private => 'Private',
      StudyCategory.likes => 'Liked',
    };

// TODO l10n
String studyListOrderL10n(StudyListOrder order, BuildContext context) =>
    switch (order) {
      StudyListOrder.hot => 'Hot',
      StudyListOrder.newest => 'Newest',
      StudyListOrder.oldest => 'Oldest',
      StudyListOrder.updated => 'Updated',
      StudyListOrder.popular => 'Popular',
    };

/// A screen that displays a paginated list of studies
class StudyListScreen extends ConsumerWidget {
  const StudyListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.read(authSessionProvider)?.user.id != null;

    final filter = ref.watch(studyFilterProvider);
    final categorySection =
        isLoggedIn ? ' • ${studyCategoryL10n(filter.category, context)}' : '';
    final title = Text(
      '${context.l10n.studyMenu}$categorySection • ${studyListOrderL10n(filter.order, context)}',
    );

    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: title,
        actions: [
          AppBarIconButton(
            icon: const Icon(Icons.tune),
            semanticsLabel: 'Filter studies',
            onPressed: () => showAdaptiveBottomSheet<void>(
              context: context,
              builder: (_) => _StudyFilterSheet(
                isLoggedIn: isLoggedIn,
              ),
            ),
          ),
        ],
      ),
      body: _Body(
        filter: ref.watch(studyFilterProvider),
      ),
    );
  }
}

class _StudyFilterSheet extends ConsumerWidget {
  const _StudyFilterSheet({required this.isLoggedIn});

  final bool isLoggedIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(studyFilterProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12.0),
            // If we're not logged in, the only category available is "All"
            if (isLoggedIn) ...[
              Filter<StudyCategory>(
                // TODO l10n
                filterName: 'Category',
                filterType: FilterType.singleChoice,
                choices: StudyCategory.values,
                choiceSelected: (choice) => filter.category == choice,
                choiceLabel: (category) => studyCategoryL10n(category, context),
                onSelected: (value, selected) =>
                    ref.read(studyFilterProvider.notifier).setCategory(value),
              ),
              const PlatformDivider(thickness: 1, indent: 0),
              const SizedBox(height: 10.0),
            ],
            Filter<StudyListOrder>(
              // TODO l10n
              filterName: 'Sort by',
              filterType: FilterType.singleChoice,
              choices: StudyListOrder.values,
              choiceSelected: (choice) => filter.order == choice,
              choiceLabel: (order) => studyListOrderL10n(order, context),
              onSelected: (value, selected) =>
                  ref.read(studyFilterProvider.notifier).setOrder(value),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatefulWidget {
  const _Body({
    required this.filter,
  });

  final StudyFilterState filter;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  String? search;

  final _searchController = SearchController();

  @override
  void dispose() {
    super.dispose();
    _searchController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: Styles.bodySectionPadding,
            child: SearchBar(
              controller: _searchController,
              leading: const Icon(Icons.search),
              trailing: [
                if (search != null)
                  IconButton(
                    onPressed: () => setState(() {
                      search = null;
                      _searchController.clear();
                    }),
                    tooltip: 'Clear',
                    icon: const Icon(
                      Icons.close,
                    ),
                  ),
              ],
              hintText: search ?? context.l10n.searchSearch,
              onSubmitted: (term) {
                setState(() {
                  search = term;
                });
              },
            ),
          ),
          _StudyList(
            paginatorProvider: StudyListPaginatorProvider(
              filter: widget.filter,
              search: search,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudyList extends ConsumerStatefulWidget {
  const _StudyList({
    required this.paginatorProvider,
  });

  final StudyListPaginatorProvider paginatorProvider;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _StudyListState();
}

class _StudyListState extends ConsumerState<_StudyList> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      final studiesList = ref.read(widget.paginatorProvider);

      if (!studiesList.isLoading) {
        ref.read(widget.paginatorProvider.notifier).next();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final studiesAsync = ref.watch(widget.paginatorProvider);

    return studiesAsync.when(
      data: (studies) {
        return Expanded(
          child: ListView.separated(
            controller: _scrollController,
            itemCount: studies.studies.length,
            separatorBuilder: (context, index) => const PlatformDivider(
              height: 1,
              cupertinoHasLeading: true,
            ),
            itemBuilder: (context, index) {
              final study = studies.studies[index];
              return PlatformListTile(
                padding: Styles.bodyPadding,
                title: Row(
                  children: [
                    _StudyFlair(
                      flair: study.flair,
                      size: 40,
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          study.name,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        _StudySubtitle(
                          study: study,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                subtitle: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _StudyChapters(study: study),
                    ),
                    Expanded(
                      child: _StudyMembers(
                        study: study,
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  StudyRepository(ref.read(lichessClientProvider))
                      .getStudy(
                    id: study.id,
                  )
                      .then((study) {
                    print('Got study: $study');
                  });
                },
              );
            },
          ),
        );
      },
      loading: () {
        return const Center(child: CircularProgressIndicator.adaptive());
      },
      error: (error, stack) {
        _logger.severe('Error loading studies', error, stack);
        return Center(child: Text(context.l10n.studyMenu));
      },
    );
  }
}

class _StudyChapters extends StatelessWidget {
  const _StudyChapters({
    required this.study,
  });

  final StudyPageData study;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...study.chapters.map(
          (chapter) => Text.rich(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            TextSpan(
              children: [
                WidgetSpan(
                  child: Icon(
                    Icons.circle_outlined,
                    size: DefaultTextStyle.of(context).style.fontSize,
                  ),
                ),
                TextSpan(
                  text: ' $chapter',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StudyMembers extends StatelessWidget {
  const _StudyMembers({
    required this.study,
  });

  final StudyPageData study;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...study.members.map(
          (member) => Text.rich(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            TextSpan(
              children: [
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Icon(
                    LichessIcons.radio_tower_lichess,
                    size: DefaultTextStyle.of(context).style.fontSize,
                  ),
                ),
                const TextSpan(text: ' '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.bottom,
                  child: UserFullNameWidget(
                    user: member.user,
                    showFlair: false,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StudyFlair extends StatelessWidget {
  const _StudyFlair({required this.flair, required this.size});

  final String? flair;

  final double size;

  @override
  Widget build(BuildContext context) {
    final iconIfNoFlair = Icon(
      LichessIcons.book_lichess,
      size: size,
    );

    return (flair != null)
        ? CachedNetworkImage(
            imageUrl: lichessFlairSrc(flair!),
            errorWidget: (_, __, ___) => iconIfNoFlair,
            width: size,
            height: size,
          )
        : iconIfNoFlair;
  }
}

class _StudySubtitle extends StatelessWidget {
  const _StudySubtitle({
    required this.study,
    required this.style,
  });

  final StudyPageData study;

  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Icon(
              Icons.favorite_outline,
              size: style.fontSize,
            ),
          ),
          TextSpan(text: ' ${study.likes}', style: style),
          TextSpan(text: ' • ', style: style),
          if (study.owner != null) ...[
            WidgetSpan(
              alignment: PlaceholderAlignment.bottom,
              child: UserFullNameWidget(
                user: study.owner,
                style: style,
                showFlair: false,
              ),
            ),
            TextSpan(text: ' • ', style: style),
          ],
          TextSpan(
            text: timeago.format(
              study.updatedAt,
            ),
            style: style,
          ),
        ],
      ),
    );
  }
}
