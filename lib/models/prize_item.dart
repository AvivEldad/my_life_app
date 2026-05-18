class PrizeItem {
  final String id;
  final String title;
  final double cost;
  final bool isRedeemed;

  PrizeItem({
    required this.id,
    required this.title,
    required this.cost,
    this.isRedeemed = false,
  });
}