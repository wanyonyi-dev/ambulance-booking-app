enum RequestStatus {
  pending,
  accepted,
  completed,
  cancelled;

  static RequestStatus fromString(String status) {
    return RequestStatus.values.firstWhere(
          (element) => element.name.toLowerCase() == status.toLowerCase(),
      orElse: () => throw ArgumentError('Invalid status: $status'),
    );
  }

  String toDisplayString() {
    switch (this) {
      case RequestStatus.pending:
        return 'Pending';
      case RequestStatus.accepted:
        return 'Accepted';
      case RequestStatus.completed:
        return 'Completed';
      case RequestStatus.cancelled:
        return 'Cancelled';
    }
  }

  @override
  String toString() => name.toLowerCase();
}