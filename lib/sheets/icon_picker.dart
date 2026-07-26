import 'package:flutter/material.dart';

import '../icons.dart';
import '../motion.dart';
import '../theme.dart';

Future<String?> showIconPicker(BuildContext context, {required String current}) {
  return showModalBottomSheet<String>(
    context: context,
    // Pick-one-and-dismiss, so it moves at menu pace rather than form pace.
    sheetAnimationStyle: Motion.menu,
    builder: (context) {
      final harbor = context.harbor;
      return SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 5,
              margin: const EdgeInsets.only(top: 8, bottom: 10),
              decoration: BoxDecoration(
                color: harbor.line,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Text(
              'Choose an icon',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: harbor.ink,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: GridView.count(
                crossAxisCount: 6,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                children: [
                  for (final icon in curatedIcons)
                    InkWell(
                      onTap: () => Navigator.of(context).pop(icon),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: icon == current ? harbor.accentSoft : null,
                          border: icon == current
                              ? Border.all(color: harbor.accent, width: 1.5)
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(icon, style: const TextStyle(fontSize: 24)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
