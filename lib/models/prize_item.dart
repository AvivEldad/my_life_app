class PrizeItem {
  final String id;
  String title;
  double cost;
  bool isRedeemed;

  PrizeItem({
    required this.id,
    required this.title,
    required this.cost,
    this.isRedeemed = false,
  });
}