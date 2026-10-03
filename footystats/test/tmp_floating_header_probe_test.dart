// TEMPORARY probe - deleted after the run.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('showOnScreen re-expands floating SliverAppBar without scrolling',
      (tester) async {
    final controller = ScrollController();
    final headerKey = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CustomScrollView(
          controller: controller,
          slivers: [
            SliverAppBar(
              floating: true,
              snap: true,
              automaticallyImplyLeading: false,
              toolbarHeight: 164,
              expandedHeight: 164,
              flexibleSpace: Padding(
                key: headerKey,
                padding: const EdgeInsets.all(16),
                child: const Text('HEADER'),
              ),
            ),
            SliverList.builder(
              itemCount: 60,
              itemBuilder: (_, i) => SizedBox(height: 100, child: Text('row $i')),
            ),
          ],
        ),
      ),
    ));

    RenderSliverFloatingPersistentHeader header() {
      RenderObject? ro = headerKey.currentContext!.findRenderObject();
      while (ro != null && ro is! RenderSliverFloatingPersistentHeader) {
        ro = ro.parent;
      }
      return ro! as RenderSliverFloatingPersistentHeader;
    }

    // Scroll forward (down) so the floating header hides.
    controller.jumpTo(1000);
    await tester.pump();
    // Simulate a user drag forward so the header's internal state hides it.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();
    final before = controller.offset;
    // ignore: avoid_print
    print('offset before=$before paintExtent=${header().geometry!.paintExtent}');
    expect(header().geometry!.paintExtent, 0);

    header().maybeStartSnapAnimation(ScrollDirection.forward);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // ignore: avoid_print
    print('mid offset=${controller.offset} paintExtent=${header().geometry!.paintExtent}');
    await tester.pumpAndSettle();
    // ignore: avoid_print
    print('offset after=${controller.offset} paintExtent=${header().geometry!.paintExtent}');
    expect(controller.offset, before, reason: 'list must not move');
    expect(header().geometry!.paintExtent, 164, reason: 'header must be shown');
  });
}
