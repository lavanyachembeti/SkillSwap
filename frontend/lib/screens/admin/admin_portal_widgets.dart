import 'package:flutter/material.dart';

/// Format ISO-8601 date string into a readable short date/time string.
String formatAdminTimestamp(String? raw) {
  if (raw == null || raw.trim().isEmpty) return 'Never';
  final dt = DateTime.tryParse(raw.trim());
  if (dt == null) return raw;
  final local = dt.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $hh:$mm';
}

/// Format ISO-8601 date string into YYYY-MM-DD.
String formatAdminShortDate(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '—';
  final dt = DateTime.tryParse(raw.trim());
  if (dt == null) return raw;
  final local = dt.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

class AdminStatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const AdminStatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  factory AdminStatusBadge.forAccountStatus(String status) {
    final normalized = status.toLowerCase().trim();
    switch (normalized) {
      case 'active':
        return const AdminStatusBadge(
          label: 'Active',
          color: Color(0xFF10B981),
          icon: Icons.check_circle_outline_rounded,
        );
      case 'suspended':
        return const AdminStatusBadge(
          label: 'Suspended',
          color: Color(0xFFEF4444),
          icon: Icons.block_rounded,
        );
      case 'inactive':
        return const AdminStatusBadge(
          label: 'Inactive',
          color: Color(0xFF94A3B8),
          icon: Icons.pause_circle_outline_rounded,
        );
      case 'pending_verification':
        return const AdminStatusBadge(
          label: 'Pending Verification',
          color: Color(0xFFF59E0B),
          icon: Icons.hourglass_bottom_rounded,
        );
      default:
        return AdminStatusBadge(
          label: status,
          color: const Color(0xFF38BDF8),
        );
    }
  }

  factory AdminStatusBadge.forRequestStatus(String status) {
    final normalized = status.toLowerCase().trim();
    switch (normalized) {
      case 'accepted':
        return const AdminStatusBadge(
          label: 'Accepted',
          color: Color(0xFF10B981),
          icon: Icons.check_circle_outline_rounded,
        );
      case 'pending':
        return const AdminStatusBadge(
          label: 'Pending',
          color: Color(0xFFF59E0B),
          icon: Icons.schedule_rounded,
        );
      case 'rejected':
        return const AdminStatusBadge(
          label: 'Rejected',
          color: Color(0xFFEF4444),
          icon: Icons.cancel_outlined,
        );
      case 'cancelled':
        return const AdminStatusBadge(
          label: 'Cancelled',
          color: Color(0xFF94A3B8),
          icon: Icons.remove_circle_outline_rounded,
        );
      default:
        return AdminStatusBadge(
          label: status,
          color: const Color(0xFF38BDF8),
        );
    }
  }

  factory AdminStatusBadge.forReportStatus(String status) {
    final normalized = status.toLowerCase().trim();
    switch (normalized) {
      case 'pending':
        return const AdminStatusBadge(
          label: 'Pending',
          color: Color(0xFFF59E0B),
          icon: Icons.warning_amber_rounded,
        );
      case 'under_review':
        return const AdminStatusBadge(
          label: 'Under Review',
          color: Color(0xFF38BDF8),
          icon: Icons.manage_search_rounded,
        );
      case 'resolved':
        return const AdminStatusBadge(
          label: 'Resolved',
          color: Color(0xFF10B981),
          icon: Icons.task_alt_rounded,
        );
      case 'dismissed':
        return const AdminStatusBadge(
          label: 'Dismissed',
          color: Color(0xFF94A3B8),
          icon: Icons.do_not_disturb_on_outlined,
        );
      default:
        return AdminStatusBadge(
          label: status,
          color: const Color(0xFFA78BFA),
        );
    }
  }

  factory AdminStatusBadge.forConversationStatus(String status) {
    final normalized = status.toLowerCase().trim();
    switch (normalized) {
      case 'active':
        return const AdminStatusBadge(
          label: 'Active (Accepted Swap)',
          color: Color(0xFF10B981),
          icon: Icons.verified_rounded,
        );
      case 'authorized_legacy':
        return const AdminStatusBadge(
          label: 'Authorized Legacy',
          color: Color(0xFF38BDF8),
          icon: Icons.admin_panel_settings_rounded,
        );
      case 'read_only_legacy':
        return const AdminStatusBadge(
          label: 'Legacy (Read-Only)',
          color: Color(0xFFF59E0B),
          icon: Icons.lock_clock_rounded,
        );
      case 'restricted':
        return const AdminStatusBadge(
          label: 'Restricted / Locked',
          color: Color(0xFFEF4444),
          icon: Icons.lock_rounded,
        );
      default:
        return AdminStatusBadge(
          label: status,
          color: const Color(0xFF94A3B8),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AdminStatMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const AdminStatMetricCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  if (onTap != null)
                    const Icon(
                      Icons.open_in_new_rounded,
                      size: 14,
                      color: Color(0xFF64748B),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFCBD5E1),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 10.5,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminPaginationFooter extends StatelessWidget {
  final int count;
  final int page;
  final int totalPages;
  final bool hasPrevious;
  final bool hasNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const AdminPaginationFooter({
    super.key,
    required this.count,
    required this.page,
    required this.totalPages,
    required this.hasPrevious,
    required this.hasNext,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          Text(
            'Total records: $count • Page $page of $totalPages',
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: hasPrevious ? onPrevious : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 38),
                  side: const BorderSide(color: Color(0xFF475569)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                icon: const Icon(Icons.chevron_left_rounded, size: 18),
                label: const Text('Previous'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: hasNext ? onNext : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 38),
                  side: const BorderSide(color: Color(0xFF475569)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                icon: const Icon(Icons.chevron_right_rounded, size: 18),
                label: const Text('Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AdminEmptyOrErrorState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isError;

  const AdminEmptyOrErrorState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isError ? const Color(0xFFEF4444) : const Color(0xFF6366F1);
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        padding: const EdgeInsets.all(28),
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isError
                ? const Color(0xFFEF4444).withValues(alpha: 0.4)
                : const Color(0xFF334155),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accent, size: 34),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 42),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
