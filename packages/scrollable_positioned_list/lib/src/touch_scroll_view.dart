import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

class TouchScrollView extends StatefulWidget {
  const TouchScrollView({
    required this.child,
    required this.controller,
    this.scrollDirection = Axis.vertical,
  });

  final Widget child;
  final ScrollController controller;
  final Axis scrollDirection;

  @override
  _TouchScrollViewState createState() => _TouchScrollViewState();
}

class _TouchScrollViewState extends State<TouchScrollView>
    with SingleTickerProviderStateMixin {
  late ScrollController _controller;

  late AnimationController _animationController;

  Queue<double> _velocities = Queue.from([0, 0]);

  late Duration _lastUpdateTime;

  bool _isInternalUpdate = false;

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

    _controller = widget.controller;

    _controller.addListener(_onScrollControllerChange);
  }

  void _onScrollControllerChange() {
    if (!_isInternalUpdate && _animationController.isAnimating) {
      _animationController.stop();
    }
  }

  void _update() {
    if (_controller.hasClients) {
      _isInternalUpdate = true;
      _controller.jumpTo(
        min(
          max(
            _controller.position.minScrollExtent,
            _animationController.value,
          ),
          _controller.position.maxScrollExtent,
        ),
      );
      _isInternalUpdate = false;
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
    _controller.removeListener(_onScrollControllerChange);

    _animationController.removeListener(_update);
    _animationController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (details) {
        if (!_controller.hasClients) return;

        _animationController.stop();
        _velocities = Queue.from([0, 0]);
      },
      onPointerMove: (details) {
        if (!_controller.hasClients) return;

        final dt =
            (details.timeStamp - _lastUpdateTime).inMilliseconds / 1000.0;
        _lastUpdateTime = details.timeStamp;

        final delta = widget.scrollDirection == Axis.vertical
            ? details.delta.dy
            : details.delta.dx;
        _controller.jumpTo(_controller.offset - delta);

        _velocities.removeFirst();
        _velocities.addLast(delta / dt);
      },
      onPointerUp: (details) {
        if (!_controller.hasClients ||
            _controller.offset < _controller.position.minScrollExtent ||
            _controller.offset > _controller.position.maxScrollExtent) {
          return;
        }
        _startInertiaScroll(_velocities.last);
      },
      child: Stack(children: [widget.child]),
    );
  }
}
