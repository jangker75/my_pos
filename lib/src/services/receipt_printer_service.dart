import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import '../models/transaction_model.dart';

/// Service untuk generate dan print struk transaksi
class ReceiptPrinterService {
  static final ReceiptPrinterService _instance =
      ReceiptPrinterService._internal();
  factory ReceiptPrinterService() => _instance;
  ReceiptPrinterService._internal();

  // =====================
  // PDF Receipt Generation
  // =====================

  /// Generate PDF struk dari TransactionModel
  Future<Uint8List> generateReceiptPdf(TransactionModel transaction) async {
    final pdf = pw.Document();
    final items = transaction.getItemsList();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: pw.EdgeInsets.all(8),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Header
              pw.Text(
                'KOPILIBRASI',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Jl. Kapling Tipar Timur Blok B no. 8',
                style: pw.TextStyle(fontSize: 10),
              ),
              pw.Text(
                'Telp: 0813-1052-5703',
                style: pw.TextStyle(fontSize: 10),
              ),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 1),
              pw.SizedBox(height: 4),

              // Transaction Info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('No:', style: pw.TextStyle(fontSize: 10)),
                  pw.Text(transaction.txnNumber,
                      style: pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Tanggal:', style: pw.TextStyle(fontSize: 10)),
                  pw.Text(_formatDateTime(transaction.createdAt),
                      style: pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Customer:', style: pw.TextStyle(fontSize: 10)),
                  pw.Text(transaction.customer,
                      style: pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Pembayaran:', style: pw.TextStyle(fontSize: 10)),
                  pw.Text(transaction.paymentMethod ?? '-',
                      style: pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 1),
              pw.SizedBox(height: 4),

              // Items
              ...items.map((it) {
                final qty = it['qty'] ?? 0;
                final price = it['price'] ?? 0;
                final disc = it['discount'] ?? 0;
                final discType = it['discountType'] ?? 'nominal';
                final lineTotal = discType == 'percentage'
                    ? (qty * price - ((qty * price * disc) ~/ 100))
                    : (qty * price - disc);

                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('${it['name']}',
                        style: pw.TextStyle(fontSize: 10)),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('  $qty x ${_formatCurrency(price)}',
                            style: pw.TextStyle(fontSize: 9)),
                        pw.Text(_formatCurrency(lineTotal),
                            style: pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                    if (disc > 0)
                      pw.Text(
                        '  Disc: ${discType == 'percentage' ? '$disc%' : _formatCurrency(disc)}',
                        style: pw.TextStyle(fontSize: 8, color: PdfColors.red),
                      ),
                    pw.SizedBox(height: 2),
                  ],
                );
              }).toList(),

              pw.SizedBox(height: 4),
              pw.Divider(thickness: 1),
              pw.SizedBox(height: 4),

              // Total
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL',
                      style: pw.TextStyle(
                          fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.Text(_formatCurrency(transaction.total.toInt()),
                      style: pw.TextStyle(
                          fontSize: 12, fontWeight: pw.FontWeight.bold)),
                ],
              ),

              // Notes
                pw.SizedBox(height: 8),
                pw.Text('Catatan: ${transaction.notes ?? "-"}',
                    style: pw.TextStyle(fontSize: 9)),
              // if ((transaction.notes ?? '').isNotEmpty) ...[
              // ],

              pw.SizedBox(height: 8),
              pw.Builder(builder: (_) {
                String statusText;
                if (transaction.status == 'paid') {
                  statusText = 'LUNAS';
                } else if (transaction.status == 'canceled') {
                  statusText = 'BATAL';
                } else {
                  statusText = 'ON PROGRESS';
                }
                return pw.Text('Status: ${statusText}',style: pw.TextStyle(fontSize: 9));
              }),
                

              pw.SizedBox(height: 12),
              pw.Divider(thickness: 1),
              pw.SizedBox(height: 8),

              // Footer
              pw.Text(
                'Terima Kasih',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Selamat Menikmati!',
                style: pw.TextStyle(fontSize: 10),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Preview dan print PDF struk
  Future<void> printPdfReceipt(TransactionModel transaction) async {
    final pdfData = await generateReceiptPdf(transaction);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfData,
      name: 'Struk_${transaction.txnNumber}',
    );
  }

  /// Share PDF struk
  Future<void> sharePdfReceipt(TransactionModel transaction) async {
    final pdfData = await generateReceiptPdf(transaction);
    await Printing.sharePdf(
      bytes: pdfData,
      filename: 'Struk_${transaction.txnNumber}.pdf',
    );
  }

  // =====================
  // Bluetooth Thermal Printer
  // =====================

  /// Request Bluetooth permissions for Android 12+
  Future<bool> _requestBluetoothPermissions() async {
    // For Android 12+ (API 31+), we need BLUETOOTH_CONNECT and BLUETOOTH_SCAN
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.bluetooth,
      Permission.location, // Some devices need location for Bluetooth scanning
    ].request();

    // Check if all critical permissions are granted
    final connectGranted = statuses[Permission.bluetoothConnect]?.isGranted ?? false;
    final scanGranted = statuses[Permission.bluetoothScan]?.isGranted ?? false;
    final bluetoothGranted = statuses[Permission.bluetooth]?.isGranted ?? false;
    
    // For older Android versions, bluetooth permission is enough
    // For newer versions, we need connect and scan
    return bluetoothGranted || (connectGranted && scanGranted);
  }

  /// Check if Bluetooth is available and on
  Future<bool> isBluetoothAvailable() async {
    try {
      return await PrintBluetoothThermal.bluetoothEnabled;
    } catch (e) {
      return false;
    }
  }

  /// Check if connected to a device
  Future<bool> isConnected() async {
    try {
      return await PrintBluetoothThermal.connectionStatus;
    } catch (e) {
      return false;
    }
  }

  /// Get paired Bluetooth devices
  Future<List<BluetoothInfo>> getPairedDevices() async {
    try {
      return await PrintBluetoothThermal.pairedBluetooths;
    } catch (e) {
      return [];
    }
  }

  /// Connect to a Bluetooth device
  Future<bool> connectToDevice(String macAddress) async {
    try {
      return await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
    } catch (e) {
      return false;
    }
  }

  /// Disconnect from current device
  Future<void> disconnect() async {
    try {
      await PrintBluetoothThermal.disconnect;
    } catch (e) {
      // ignore
    }
  }

  /// Print struk ke printer thermal Bluetooth
  Future<bool> printThermalReceipt(TransactionModel transaction) async {
    try {
      final isConnectedNow = await isConnected();
      if (!isConnectedNow) {
        return false;
      }

      final items = transaction.getItemsList();
      List<int> bytes = [];

      // ESC/POS commands
      // Initialize printer
      bytes += [0x1B, 0x40]; // ESC @

      // Center align
      bytes += [0x1B, 0x61, 0x01]; // ESC a 1

      // Header - bold and double size
      bytes += [0x1B, 0x45, 0x01]; // Bold on
      bytes += [0x1D, 0x21, 0x11]; // Double width & height
      bytes += _textToBytes('KOPILIBRASI\n');
      bytes += [0x1D, 0x21, 0x00]; // Normal size
      bytes += [0x1B, 0x45, 0x00]; // Bold off

      bytes += _textToBytes('Jl. Tipar Timur Blok B no. 8\n');
      bytes += _textToBytes('Telp: 0813-1052-5703\n');
      bytes += _textToBytes('\n');

      // Left align
      bytes += [0x1B, 0x61, 0x00]; // ESC a 0

      // Separator
      bytes += _textToBytes('================================\n');

      // Transaction Info
      bytes += _textToBytes('No: ${transaction.txnNumber}\n');
      bytes += _textToBytes('Tgl: ${_formatDateTime(transaction.createdAt)}\n');
      bytes += _textToBytes('Customer: ${transaction.customer}\n');
      bytes += _textToBytes('Bayar: ${transaction.paymentMethod ?? '-'}\n');

      bytes += _textToBytes('================================\n');

      // Items
      for (final it in items) {
        final name = it['name'] ?? '';
        final qty = it['qty'] ?? 0;
        final price = it['price'] ?? 0;
        final disc = it['discount'] ?? 0;
        final discType = it['discountType'] ?? 'nominal';
        final lineTotal = discType == 'percentage'
            ? (qty * price - ((qty * price * disc) ~/ 100))
            : (qty * price - disc);

        bytes += _textToBytes('$name\n');
        bytes += _textToBytes('  $qty x ${_formatCurrency(price)}\n');
        
        // Right align for price
        final priceStr = _formatCurrency(lineTotal);
        final spaces = 32 - priceStr.length;
        bytes += _textToBytes('${' ' * spaces}$priceStr\n');

        if (disc > 0) {
          final discStr =
              discType == 'percentage' ? '$disc%' : _formatCurrency(disc);
          bytes += _textToBytes('  Disc: $discStr\n');
        }
      }

      bytes += _textToBytes('================================\n');

      // Total - bold
      bytes += [0x1B, 0x45, 0x01]; // Bold on
      final totalStr = _formatCurrency(transaction.total.toInt());
      bytes += _textToBytes('TOTAL');
      final totalSpaces = 32 - 5 - totalStr.length;
      bytes += _textToBytes('${' ' * totalSpaces}$totalStr\n');
      bytes += [0x1B, 0x45, 0x00]; // Bold off

      // Notes
      if ((transaction.notes ?? '').isNotEmpty) {
        bytes += _textToBytes('\n');
        bytes += _textToBytes('Catatan: ${transaction.notes}\n');
      }

      bytes += _textToBytes('\n');
      bytes += _textToBytes('--------------------------------\n');

      // Center align for footer
      bytes += [0x1B, 0x61, 0x01]; // ESC a 1
      bytes += [0x1B, 0x45, 0x01]; // Bold on
      bytes += _textToBytes('Terima Kasih\n');
      bytes += [0x1B, 0x45, 0x00]; // Bold off
      bytes += _textToBytes('Selamat Menikmati!\n');

      // Feed paper
      bytes += _textToBytes('\n\n\n');

      // Cut paper (if supported)
      bytes += [0x1D, 0x56, 0x00]; // GS V 0

      // Send to printer
      final result = await PrintBluetoothThermal.writeBytes(bytes);
      return result;
    } catch (e) {
      return false;
    }
  }

  /// Convert text to bytes
  List<int> _textToBytes(String text) {
    return text.codeUnits;
  }

  // =====================
  // Helper Methods
  // =====================

  String _formatDateTime(String isoString) {
    final dt = DateTime.tryParse(isoString) ?? DateTime.now();
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatCurrency(int value) {
    final s = value.toString();
    final parts = <String>[];
    for (int i = s.length; i > 0; i -= 3) {
      final start = i - 3 < 0 ? 0 : i - 3;
      parts.insert(0, s.substring(start, i));
    }
    return 'Rp ${parts.join('.')}';
  }

  /// Show dialog to select print method
  Future<void> showPrintDialog(
      BuildContext context, TransactionModel transaction) async {
    await showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Print Struk',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                ListTile(
                  leading: Icon(Icons.picture_as_pdf, color: Colors.red),
                  title: Text('Preview / Print PDF'),
                  subtitle: Text('Preview struk dan print ke printer biasa'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await printPdfReceipt(transaction);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.share, color: Colors.blue),
                  title: Text('Share PDF'),
                  subtitle: Text('Bagikan struk sebagai file PDF'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await sharePdfReceipt(transaction);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.print, color: Colors.green),
                  title: Text('Printer Thermal Bluetooth'),
                  subtitle: Text('Print ke printer kasir via Bluetooth'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _showBluetoothPrinterDialog(context, transaction);
                  },
                ),
                SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Show dialog to connect and print to Bluetooth thermal printer
  Future<void> _showBluetoothPrinterDialog(
      BuildContext context, TransactionModel transaction) async {
    
    // Request Bluetooth permissions first
    final permissionsGranted = await _requestBluetoothPermissions();
    if (!permissionsGranted) {
      _showSnackBar(context, 'Izin Bluetooth diperlukan untuk mencetak. Silakan aktifkan di Pengaturan.');
      return;
    }

    // Check Bluetooth availability
    final available = await isBluetoothAvailable();
    if (!available) {
      _showSnackBar(context, 'Mohon aktifkan Bluetooth terlebih dahulu');
      return;
    }

    // Show loading while getting devices
    _showLoadingDialog(context, 'Mencari printer...');

    // Check if already connected
    final connected = await isConnected();
    if (connected) {
      Navigator.pop(context); // close loading
      // Directly print
      _showLoadingDialog(context, 'Mencetak...');
      final success = await printThermalReceipt(transaction);
      Navigator.pop(context); // close loading
      if (success) {
        _showSnackBar(context, 'Struk berhasil dicetak!');
      } else {
        _showSnackBar(context, 'Gagal mencetak struk');
      }
      return;
    }

    // Show device selection dialog
    final devices = await getPairedDevices();
    Navigator.pop(context); // close loading
    
    if (devices.isEmpty) {
      _showSnackBar(
          context, 'Tidak ada printer Bluetooth yang dipasangkan. Silakan pasangkan printer di pengaturan Bluetooth HP.');
      return;
    }

    // ignore: use_build_context_synchronously
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Pilih Printer'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: devices.length,
              itemBuilder: (_, index) {
                final device = devices[index];
                return ListTile(
                  leading: Icon(Icons.print),
                  title: Text(device.name),
                  subtitle: Text(device.macAdress),
                  onTap: () async {
                    // Close device selection dialog first
                    Navigator.pop(dialogContext);
                    
                    // Use root navigator context for subsequent dialogs
                    await _connectAndPrint(context, device.macAdress, transaction);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Batal'),
            ),
          ],
        );
      },
    );
  }

  /// Helper method to connect and print - handles its own dialogs
  Future<void> _connectAndPrint(
      BuildContext context, String macAddress, TransactionModel transaction) async {
    // Show connecting dialog
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Menghubungkan...'),
          ],
        ),
      ),
    );

    final success = await connectToDevice(macAddress);
    
    // Close connecting dialog
    if (navigator.canPop()) {
      navigator.pop();
    }

    if (success) {
      // Show printing dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Mencetak...'),
            ],
          ),
        ),
      );

      final printed = await printThermalReceipt(transaction);
      
      // Close printing dialog
      if (navigator.canPop()) {
        navigator.pop();
      }

      if (printed) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Struk berhasil dicetak!')),
        );
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Gagal mencetak struk')),
        );
      }
    } else {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Gagal terhubung ke printer')),
      );
    }
  }

  void _showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
