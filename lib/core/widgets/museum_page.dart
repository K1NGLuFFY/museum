import 'package:flutter/cupertino.dart';

import '../theme/museum_theme.dart';

class MuseumPage extends StatelessWidget {
  const MuseumPage({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    child: SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Semantics(
                              header: true,
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontSize: title == 'MUSEUM' ? 29 : 34,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: title == 'MUSEUM' ? 4 : -1.2,
                                ),
                              ),
                            ),
                          ),
                          ?trailing,
                        ],
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 14,
                            color: MuseumColors.resolve(
                              MuseumColors.secondary,
                              context,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                      ...children,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.eyebrow});
  final String title;
  final String? eyebrow;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (eyebrow != null) ...[
        Text(
          eyebrow!.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
            color: MuseumColors.resolve(MuseumColors.accent, context),
          ),
        ),
        const SizedBox(height: 10),
      ],
      Semantics(
        header: true,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.6,
          ),
        ),
      ),
      const SizedBox(height: 18),
    ],
  );
}
