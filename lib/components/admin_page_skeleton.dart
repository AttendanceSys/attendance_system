import 'package:flutter/material.dart';

class AdminsPageSkeleton extends StatelessWidget {
  const AdminsPageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const _TableOnlySkeleton(columnFlexes: [12, 26, 30, 24], rows: 11);
  }
}

class FacultiesPageSkeleton extends StatelessWidget {
  const FacultiesPageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const _TableOnlySkeleton(columnFlexes: [14, 22, 36, 28], rows: 11);
  }
}

class DepartmentsPageSkeleton extends StatelessWidget {
  const DepartmentsPageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const _TableOnlySkeleton(
      columnFlexes: [12, 20, 28, 24, 16],
      rows: 11,
    );
  }
}

class ClassesPageSkeleton extends StatelessWidget {
  const ClassesPageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const _TableOnlySkeleton(columnFlexes: [12, 34, 32, 22], rows: 11);
  }
}

class LecturersPageSkeleton extends StatelessWidget {
  const LecturersPageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const _TableOnlySkeleton(columnFlexes: [12, 24, 36, 28], rows: 11);
  }
}

class CoursesPageSkeleton extends StatelessWidget {
  const CoursesPageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const _TableOnlySkeleton(
      columnFlexes: [8, 16, 22, 18, 16, 20],
      rows: 11,
    );
  }
}

class StudentsPageSkeleton extends StatelessWidget {
  const StudentsPageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const _TableOnlySkeleton(
      columnFlexes: [8, 20, 22, 10, 24, 16],
      rows: 11,
    );
  }
}

class _TableOnlySkeleton extends StatelessWidget {
  final List<int> columnFlexes;
  final int rows;

  const _TableOnlySkeleton({required this.columnFlexes, required this.rows});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surfaceContainerHighest.withValues(alpha: 0.55);
    final soft = scheme.surfaceContainerHigh.withValues(alpha: 0.45);
    final border = scheme.outlineVariant.withValues(alpha: 0.5);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: soft,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  _bar(20, 10, base),
                  const SizedBox(width: 16),
                  for (int i = 0; i < columnFlexes.length; i++) ...[
                    Expanded(flex: columnFlexes[i], child: _bar(0, 10, base)),
                    if (i < columnFlexes.length - 1) const SizedBox(width: 12),
                  ],
                ],
              ),
            ),
          ),
          for (int r = 0; r < rows; r++)
            Container(
              height: 44,
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.35),
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    _bar(18, 9, soft),
                    const SizedBox(width: 16),
                    for (int i = 0; i < columnFlexes.length; i++) ...[
                      Expanded(
                        flex: columnFlexes[i],
                        child: _bar(0, 9, i.isEven ? base : soft),
                      ),
                      if (i < columnFlexes.length - 1) const SizedBox(width: 12),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _bar(double width, double height, Color color) {
    return Container(
      width: width == 0 ? null : width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

class UserHandlingPageSkeleton extends StatelessWidget {
  final int rows;

  const UserHandlingPageSkeleton({super.key, this.rows = 11});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surfaceContainerHighest.withValues(alpha: 0.55);
    final soft = scheme.surfaceContainerHigh.withValues(alpha: 0.45);
    final border = scheme.outlineVariant.withValues(alpha: 0.5);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: soft,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  _pill(20, 10, base),
                  const SizedBox(width: 16),
                  Expanded(flex: 23, child: _pill(0, 10, base)),
                  const SizedBox(width: 12),
                  Expanded(flex: 20, child: _pill(0, 10, base)),
                  const SizedBox(width: 12),
                  Expanded(flex: 20, child: _pill(0, 10, base)),
                  const SizedBox(width: 12),
                  Expanded(flex: 27, child: _pill(0, 10, base)),
                ],
              ),
            ),
          ),
          for (int i = 0; i < rows; i++)
            Container(
              height: 44,
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.35),
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    _pill(18, 9, soft),
                    const SizedBox(width: 16),
                    Expanded(flex: 23, child: _pill(0, 9, base)),
                    const SizedBox(width: 12),
                    Expanded(flex: 20, child: _pill(0, 9, soft)),
                    const SizedBox(width: 12),
                    Expanded(flex: 20, child: _pill(0, 9, base)),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 27,
                      child: Row(
                        children: [
                          Expanded(child: _pill(0, 9, soft)),
                          const SizedBox(width: 10),
                          _pill(18, 9, base),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _pill(double width, double height, Color color) {
    return Container(
      width: width == 0 ? null : width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
