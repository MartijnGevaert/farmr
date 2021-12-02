import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/wallets/coldWallets/alltheblocks.dart';
import 'package:farmr_client/wallets/coldWallets/coldwallet.dart';
import 'package:farmr_client/wallets/coldWallets/localColdWallet-web.dart'
    if (dart.library.io) "package:farmr_client/wallets/coldWallets/localColdWallet.dart";
import 'package:farmr_client/wallets/localWallets/localWalletJS.dart'
    if (dart.library.io) 'package:farmr_client/wallets/localWallets/localWalletIO.dart';
import 'package:farmr_client/wallets/localWallets/localWalletStruct.dart';
import 'package:farmr_client/wallets/poolWallets/elysiumPoolWallet.dart';
import 'package:farmr_client/wallets/poolWallets/flexPoolWallet.dart';
import 'package:farmr_client/wallets/poolWallets/foxyPoolWallet.dart';
import 'package:farmr_client/wallets/poolWallets/genericPoolWallet.dart';
import 'package:farmr_client/wallets/poolWallets/plottersClubWallet.dart';
import 'package:farmr_client/wallets/poolWallets/spacePoolWallet.dart';
import 'package:farmr_client/wallets/poolWallets/xchGardenWallet.dart';
import 'package:farmr_client/wallets/wallet.dart';
import 'package:logging/logging.dart';

Logger log = Logger("HarvesterWallet");

class HarvesterWallets {
  //list of wallets
  List<Wallet> wallets = [];
  //sums all wallets into one, useful for getting latest block farmed and how many days ago -> effort
  Wallet get walletAggregate => wallets.reduce((w1, w2) => w1 + w2);

  //list of local wallets
  List<LocalWalletStruct> get localWallets => wallets
      .where((wallet) => wallet.type == WalletType.Local)
      .map((e) => e as LocalWalletStruct)
      .toList();

  //sums all local wallets into one
  LocalWalletStruct get localWalletAggregate => localWallets.reduce(
      (w1, w2) => ((w1 as LocalWalletStruct) * (w2 as LocalWalletStruct)));

  //list of cold wallets
  List<ColdWallet> get coldWallets => wallets
      .where((wallet) => wallet.type == WalletType.Cold)
      .map((e) => e as ColdWallet)
      .toList();
  //sums all cold wallets into one
  ColdWallet get coldWalletAggregate => coldWallets.reduce((w1, w2) => w1 * w2);

  //list of pool wallets
  List<GenericPoolWallet> get poolWallets => wallets
      .where((wallet) => wallet.type == WalletType.Pool)
      .map((e) => e as GenericPoolWallet)
      .toList();
  //sums all pool wallets into one
  GenericPoolWallet get poolWalletAggregate =>
      poolWallets.reduce((w1, w2) => w1 * w2);

  //selects addresses from all wallets
  List<String> get addresses => localAddresses + coldAddresses;

  //selects addresses from hot wallets
  List<String> get coldAddresses => (coldWallets.length > 0)
      ? coldWallets
          .map((e) => e.addresses)
          .reduce((l1, l2) => l1 + l2)
          .toList()
          .toSet()
          .toList()
      : [];

  //selects addresses from local wallets
  List<String> get localAddresses => (localWallets.length > 0)
      ? localWallets
          .map((e) => e.addresses)
          .reduce((l1, l2) => l1 + l2)
          .toList()
          .toSet()
          .toList()
      : [];

  String farmerRewardAddress = "N/A";
  String poolRewardAddress = "N/A";

  //final DateTime currentTime = DateTime.now();
  int syncedBlockHeight = -1;

  Future<void> getWallets(Blockchain blockchain, int syncedBlockHeight) async {
    for (String address in blockchain.config.flexpoolAddresses)
      wallets.add(FlexpoolWallet(blockchain: blockchain, address: address));

    for (String publicKey in blockchain.config.foxyPoolPublicKeys) {
      //og wallet
      if (publicKey.length == 96 ||
          publicKey.length == 98) // length difference is 0x
        wallets.add(FoxyPoolWallet(
            blockchain: blockchain,
            publicKey: publicKey,
            protocol: FoxyPoolProtocol.OG,
            name: "FoxyPool OG Wallet"));
      //nft wallet
      else if ((publicKey.length == 64 || publicKey.length == 66) &&
          blockchain.currencySymbol == "xch")
        wallets.add(FoxyPoolWallet(
            blockchain: blockchain,
            publicKey: publicKey,
            protocol: FoxyPoolProtocol.NFT,
            name: "FoxyPool NFT Wallet"));
    }

    for (String publicKey in blockchain.config.plottersClubPublicKeys)
      wallets.add(
          PlottersClubWallet(blockchain: blockchain, poolPublicKey: publicKey));

    for (String publicKey in blockchain.config.spacePoolPublicKeys)
      wallets.add(
          SpacePoolWallet(blockchain: blockchain, poolPublicKey: publicKey));

    for (String publicKey in blockchain.config.xchGardenPublicKeys)
      wallets.add(
          XchGardenWallet(blockchain: blockchain, poolPublicKey: publicKey));

    for (String launcherID in blockchain.config.elysiumPoolLauncherIDs)
      wallets.add(
          ElysiumPoolWallet(blockchain: blockchain, launcherID: launcherID));

    List<String> failedAddresses = [];
    for (Wallet wallet in wallets) {
      await wallet.init();

      //adds failed local cold wallet addresses as alltheblocks wallets
      if (wallet is LocalColdWallet && !wallet.success) {
        failedAddresses.addAll(wallet.addresses);
      }
    }

    for (final address in failedAddresses) {
      final AllTheBlocksWallet backupWallet =
          AllTheBlocksWallet(blockchain: blockchain, address: address);
      await backupWallet.init();

      wallets.add(backupWallet);
    }
  }

  void loadWalletsFromJson(dynamic object) {
    //loads wallets from json
    if (object['wallets'] != null) {
      for (var wallet in object['wallets']) {
        //detects which wallet type it is before deserializing it
        WalletType type = WalletType.values[wallet['type'] ?? 0];

        if (type == WalletType.Local)
          wallets.add(LocalWallet.fromJson(wallet));
        else if (type == WalletType.Cold)
          wallets.add(ColdWallet.fromJson(wallet));
        else if (type == WalletType.Pool)
          wallets.add(GenericPoolWallet.fromJson(wallet));
      }
    }
  }
}
