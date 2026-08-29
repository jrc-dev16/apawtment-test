import 'dart:math' as math;
import 'package:flutter/material.dart';

// -----------------------------------------------------------------------------
// SHIMMER ANIMATION WRAPPER
// -----------------------------------------------------------------------------

class ShimmerLoading extends StatefulWidget {
  final Widget child;
  const ShimmerLoading({super.key, required this.child});

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final double shimmerX = -1.0 + 3.0 * _controller.value;
            return LinearGradient(
              begin: Alignment(shimmerX - 1, 0),
              end: Alignment(shimmerX + 1, 0),
              colors: const [
                Color(0xFF2E2E2E),
                Color(0xFF404040),
                Color(0xFF505050),
                Color(0xFF404040),
                Color(0xFF2E2E2E),
              ],
              stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// PRIMITIVE SKELETON BUILDING BLOCKS
// -----------------------------------------------------------------------------

class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF3A3A3A),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

class SkeletonAvatar extends StatelessWidget {
  final double size;
  const SkeletonAvatar({super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFF3A3A3A),
        shape: BoxShape.circle,
      ),
    );
  }
}

class SkeletonTextLine extends StatelessWidget {
  final double widthFraction;
  final double height;
  const SkeletonTextLine({
    super.key,
    this.widthFraction = 1.0,
    this.height = 12,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SkeletonBox(
          width: constraints.maxWidth * widthFraction,
          height: height,
          borderRadius: 6,
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// SKELETON ACCOUNT LIST  (Account Management tabs)
// -----------------------------------------------------------------------------

class SkeletonAccountList extends StatelessWidget {
  const SkeletonAccountList({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: List.generate(3, (i) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i < 2 ? 12 : 0),
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3A3A3A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(width: 48, height: 10, borderRadius: 5),
                          const SizedBox(height: 10),
                          SkeletonBox(width: 32, height: 16, borderRadius: 5),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: ListView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 6,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SkeletonAccountCard(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonAccountCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SkeletonAvatar(size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 140, height: 13, borderRadius: 6),
                const SizedBox(height: 8),
                SkeletonBox(width: 100, height: 11, borderRadius: 6),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SkeletonBox(width: 60, height: 26, borderRadius: 20),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// SKELETON ACCOUNT DETAIL  (Sub-admin profile / edit form page)
// -----------------------------------------------------------------------------

class SkeletonAccountDetail extends StatelessWidget {
  const SkeletonAccountDetail({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2C),
              borderRadius: BorderRadius.circular(16),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SkeletonAvatar(size: 80),
                  const SizedBox(height: 16),
                  SkeletonBox(width: 160, height: 16, borderRadius: 8),
                  const SizedBox(height: 8),
                  SkeletonBox(width: 120, height: 12, borderRadius: 6),
                  const SizedBox(height: 28),
                  ..._skeletonFields(4),
                  const SizedBox(height: 20),
                  SkeletonBox(
                      width: double.infinity, height: 44, borderRadius: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static List<Widget> _skeletonFields(int count) {
    return List.generate(count, (_) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(width: 90, height: 11, borderRadius: 5),
            const SizedBox(height: 8),
            SkeletonBox(width: double.infinity, height: 40, borderRadius: 8),
          ],
        ),
      );
    });
  }
}

// -----------------------------------------------------------------------------
// SKELETON APPROVAL LIST  (Adoption approval / adoption requests)
// -----------------------------------------------------------------------------

class SkeletonApprovalList extends StatelessWidget {
  const SkeletonApprovalList({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 5,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _SkeletonApprovalCard(),
        ),
      ),
    );
  }
}

class _SkeletonApprovalCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SkeletonAvatar(size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 130, height: 13, borderRadius: 6),
                    const SizedBox(height: 7),
                    SkeletonBox(width: 90, height: 11, borderRadius: 5),
                  ],
                ),
              ),
              SkeletonBox(width: 72, height: 26, borderRadius: 20),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF3A3A3A),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                SkeletonBox(width: 48, height: 48, borderRadius: 8),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 100, height: 12, borderRadius: 5),
                    const SizedBox(height: 7),
                    SkeletonBox(width: 70, height: 10, borderRadius: 5),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SkeletonBox(
                    width: double.infinity, height: 36, borderRadius: 8),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SkeletonBox(
                    width: double.infinity, height: 36, borderRadius: 8),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// SKELETON PET TABLE  (Pet Adoptions, Ready to Adopt, Pet Profiles table views)
// -----------------------------------------------------------------------------

class SkeletonPetTable extends StatelessWidget {
  const SkeletonPetTable({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2C),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  SkeletonBox(width: 40, height: 11, borderRadius: 5),
                  const Spacer(),
                  SkeletonBox(width: 70, height: 11, borderRadius: 5),
                  const Spacer(),
                  SkeletonBox(width: 55, height: 11, borderRadius: 5),
                  const Spacer(),
                  SkeletonBox(width: 60, height: 11, borderRadius: 5),
                  const Spacer(),
                  SkeletonBox(width: 50, height: 11, borderRadius: 5),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 8,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _SkeletonPetTableRow(alternate: i.isOdd),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonPetTableRow extends StatelessWidget {
  final bool alternate;
  const _SkeletonPetTableRow({this.alternate = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: alternate ? const Color(0xFF282828) : const Color(0xFF242424),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const SkeletonAvatar(size: 32),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: SkeletonBox(
                width: double.infinity, height: 12, borderRadius: 5),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: SkeletonBox(
                width: double.infinity, height: 12, borderRadius: 5),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: SkeletonBox(
                width: double.infinity, height: 12, borderRadius: 5),
          ),
          const SizedBox(width: 10),
          SkeletonBox(width: 60, height: 24, borderRadius: 16),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// SKELETON PET GRID  (Pets with Disabilities, Medications page)
// -----------------------------------------------------------------------------

class SkeletonPetGrid extends StatelessWidget {
  final int crossAxisCount;
  const SkeletonPetGrid({super.key, this.crossAxisCount = 0});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final cols = crossAxisCount > 0
        ? crossAxisCount
        : math.max(1, (width / 220).floor());

    return ShimmerLoading(
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          childAspectRatio: 0.78,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemCount: cols * 3,
        itemBuilder: (_, __) => _SkeletonPetCard(),
      ),
    );
  }
}

class _SkeletonPetCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF3A3A3A),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 100, height: 13, borderRadius: 6),
                  const SizedBox(height: 8),
                  SkeletonBox(width: 70, height: 11, borderRadius: 5),
                  const SizedBox(height: 10),
                  SkeletonBox(
                      width: double.infinity, height: 30, borderRadius: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
