import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

class TouchScrollView extends StatefulWidget {
  const TouchScrollView({required this.child, this.controller});

  final Widget child;
  final ScrollController? controller;

  @override
  _TouchScrollViewState createState() => _TouchScrollViewState();
}

class _TouchScrollViewState extends State<TouchScrollView>
    with SingleTickerProviderStateMixin {
  late ScrollController _controller;

  late AnimationController _animationController;

  Queue<double> _velocities = Queue.from([0, 0]);

  late Duration _lastUpdateTime;

  @override
  void initState() {
    super.initState();

    _lastUpdateTime = Duration(milliseconds: 0);

    _animationController = AnimationController.unbounded(vsync: this)
      ..addListener(_update)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed ||
            status == AnimationStatus.dismissed) {
          _animationController.stop();
        }
      });

    _controller = widget.controller ?? ScrollController();
  }

  void _update() {
    if (_controller.hasClients) {
      _controller.jumpTo(
        min(
          max(0, _animationController.value),
          _controller.position.maxScrollExtent,
        ),
      );
    }
  }

  void _startInertiaScroll(double velocity) {
    final simulation = FrictionSimulation(0.05, _controller.offset, -velocity);

    _animationController
      ..stop()
      ..animateWith(simulation);
  }

  @override
  void dispose() {
    _animationController.removeListener(_update);
    _animationController.dispose();

    _controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (details) {
        _animationController.stop();
        _velocities = Queue.from([0, 0]);
      },
      onPointerMove: (details) {
        final dt =
            (details.timeStamp - _lastUpdateTime).inMilliseconds / 1000.0;
        _lastUpdateTime = details.timeStamp;

        final dy = details.delta.dy;
        _controller.jumpTo(_controller.offset - dy);

        _velocities.removeFirst();
        _velocities.addLast(dy / dt);
      },
      onPointerUp: (details) => _startInertiaScroll(_velocities.last),
      child: Stack(children: [widget.child]),
    );
  }
}
