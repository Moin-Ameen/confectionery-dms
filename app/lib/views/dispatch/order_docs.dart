import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/inventory_controller.dart';
import '../../controllers/shop_controller.dart';
import '../../controllers/user_controller.dart';
import '../../models/order.dart';
import '../../services/bt_printer_service.dart';
import '../../services/pdf_service.dart';
import '../widgets/common.dart';

/// Builds the invoice / order document for PDF, WhatsApp and Bluetooth print.
PrintDoc orderDoc(BuildContext context, SaleOrder o) {
  final inv = context.read<InventoryController>();
  final shops = context.read<ShopController>();
  final users = context.read<UserController>();
  final shop = shops.shop(o.shopId);
  final isInvoice = o.status == OrderStatus.delivered;
  return PrintDoc(
    title: isInvoice ? 'INVOICE' : 'ORDER',
    number: '#${isInvoice ? o.invoiceNo : o.no}',
    date: o.invoicedAt ?? o.date,
    partyLines: [
      shop?.name ?? '-',
      if ((shop?.khataNo ?? '').isNotEmpty) 'Khata: ${shop!.khataNo}',
      if ((shop?.phone ?? '').isNotEmpty) 'Phone: ${shop!.phone}',
      if ((shop?.area ?? '').isNotEmpty) 'Area: ${shop!.area}',
      if (o.bookerId.isNotEmpty) 'Booker: ${users.nameOf(o.bookerId)}',
      if (o.salesmanId.isNotEmpty) 'Salesman: ${users.nameOf(o.salesmanId)}',
    ],
    headers: ['Item', 'Qty', 'Free', 'Rate', 'Disc%', 'Amount'],
    rows: [
      for (final i in o.items)
        [
          inv.productName(i.productId),
          inv.product(i.productId)?.packLabel(i.qty) ?? '${i.qty}',
          '${i.freeQty}',
          num2(i.rate),
          num2(i.discountPct),
          num0(i.amount),
        ]
    ],
    totals: [
      MapEntry('Gross', money(o.gross)),
      if (o.itemDiscount > 0) MapEntry('Scheme discount', money(o.itemDiscount)),
      if (o.extraDiscount > 0) MapEntry('Extra discount', money(o.extraDiscount)),
      MapEntry('Net amount', money(o.net)),
      if (isInvoice) MapEntry('Previous balance', money(shops.outstanding(o.shopId) - o.net)),
      if (isInvoice) MapEntry('Total khata balance', money(shops.outstanding(o.shopId))),
    ],
    note: o.notes,
  );
}

Future<void> shareOrder(BuildContext context, SaleOrder o) =>
    PdfService.instance.share(orderDoc(context, o), '${o.status == OrderStatus.delivered ? 'invoice' : 'order'}_${o.no}.pdf');

Future<void> printOrder(BuildContext context, SaleOrder o) => PdfService.instance.printDoc(orderDoc(context, o));

Future<void> btPrintOrder(BuildContext context, SaleOrder o) async {
  final err = await BtPrinterService.instance.printDoc(orderDoc(context, o));
  if (context.mounted) handleResult(context, err, success: 'Sent to printer');
}
