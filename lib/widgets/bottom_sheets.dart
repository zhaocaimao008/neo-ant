import 'package:flutter/material.dart';
import '../services/l10n_helper.dart';

void showMessageActions(BuildContext context, {bool isMe = false, VoidCallback? onCopy, VoidCallback? onReply, VoidCallback? onDelete, VoidCallback? onFavorite, VoidCallback? onForward}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final bgColor = isDark ? const Color(0xFF1E254A) : Colors.white;
  final txtColor = isDark ? const Color(0xFFF0F2F5) : const Color(0xFF202124);
  final iconColor = isDark ? const Color(0xFF8E95A8) : const Color(0xFFAAAAAA);

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF252B44) : const Color(0xFFE9E9E9),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _ActionItem(Icons.content_copy, context.t('copy'), txtColor, iconColor, onTap: () { Navigator.pop(context); onCopy?.call(); }),
            _ActionItem(Icons.reply_outlined, context.t('reply'), txtColor, iconColor, onTap: () { Navigator.pop(context); onReply?.call(); }),
            if (isMe) _ActionItem(Icons.edit_outlined, context.t('edit'), txtColor, iconColor, onTap: () { Navigator.pop(context); }),
            _ActionItem(Icons.share_outlined, context.t('forward'), txtColor, iconColor, onTap: () { Navigator.pop(context); onForward?.call(); }),
            if (isMe) _ActionItem(Icons.star_outline, context.t('favorite'), txtColor, iconColor, onTap: () { Navigator.pop(context); onFavorite?.call(); }),
            if (isMe)
              _ActionItem(Icons.delete_outline, isMe ? context.t('delete') : context.t('delete'), const Color(0xFFFF3B30), const Color(0xFFFF3B30), onTap: () { Navigator.pop(context); onDelete?.call(); })
            else
              _ActionItem(Icons.delete_outline, context.t('delete'), const Color(0xFFFF3B30), const Color(0xFFFF3B30), onTap: () { Navigator.pop(context); onDelete?.call(); }),
          ],
        ),
      ),
    ),
  );
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color txtColor;
  final Color iconColor;
  final VoidCallback? onTap;
  const _ActionItem(this.icon, this.label, this.txtColor, this.iconColor, {this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? () => Navigator.pop(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 16),
              Text(label, style: TextStyle(fontSize: 15, color: txtColor)),
            ],
          ),
        ),
      ),
    );
  }
}

void showShareSheet(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final bgColor = isDark ? const Color(0xFF1E254A) : Colors.white;
  final txtColor = isDark ? const Color(0xFFF0F2F5) : const Color(0xFF202124);

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF252B44) : const Color(0xFFE9E9E9),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(context.t('forwardTo'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: txtColor)),
            const SizedBox(height: 16),
            SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _ShareContact('陈', '陈明'),
                  _ShareContact('李', '李华'),
                  _ShareContact('张', '张伟'),
                  _ShareContact('王', '王芳'),
                  _ShareContact('项', '项目A-需求讨论'),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ShareContact extends StatelessWidget {
  final String initial;
  final String name;
  const _ShareContact(this.initial, this.name);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF1AA4EC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(initial, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 60,
            child: Text(name, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
