import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:native_flutter_connect_metamask/contract.dart';
import 'package:native_flutter_connect_metamask/wallet_connect_thereum_credentials.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:walletconnect_dart/walletconnect_dart.dart';
import 'package:walletconnect_secure_storage/walletconnect_secure_storage.dart';
import 'package:web3dart/json_rpc.dart';
import 'package:web3dart/web3dart.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String? account;
  WalletConnect? connector;
  late WalletConnectSecureStorage connectSession;
  Completer? loadData;
  late EthereumWalletConnectProvider provider;
  @override
  void initState() {
    super.initState();
    connectSession = WalletConnectSecureStorage();
    loadData = Completer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Init data
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      final session = await connectSession.getSession();
      await _initialConnect(session: session);
      loadData?.complete();
    });
  }

  _initialConnect({WalletConnectSession? session}) async {
    if (connector != null) {
      await connector?.killSession();
      connector = null;
    }
    connector = WalletConnect(
      session: session,
      sessionStorage: connectSession,
      bridge: 'https://hidenxtt.bridge.walletconnect.org',
      clientMeta: const PeerMeta(
        name: 'WalletConnect',
        description: 'WalletConnect Developer App',
        url: 'https://walletconnect.org',
        icons: [
          'https://gblobscdn.gitbook.com/spaces%2F-LJJeCjcLrr53DcT1Ml7%2Favatar.png?alt=media'
        ],
      ),
    );
    // Subscribe to events
    connector?.registerListeners(
      onConnect: (status) async {
        log('Connect');
        setState(() {
          account = status.accounts[0];
        });
      },
      onDisconnect: () {
        log('Disconnect');
        setState(() {
          account = null;
        });
      },
      onSessionUpdate: (response) {
        log('Update');
        setState(() {
          account = response.accounts[0];
        });
      },
    );
    if (connector?.connected == true) {
      setState(() {
        account = connector?.session.accounts[0];
      });
    }
  }

  _walletConnect() async {
    await _initialConnect();

    // Create a new session
    if (!(connector?.connected == true)) {
      final session = await connector?.createSession(
        chainId: 80001,
        onDisplayUri: (uri) async {
          log(uri);
          await launchUrlString(uri);
        },
      );
      log('Connect : $session');
    }
  }

  _walletDisconnect() async {
    if (connector?.connected == true) {
      await connector?.killSession();
    }
  }

  _approveContract() async {
    provider = EthereumWalletConnectProvider(connector!);
    AlgorandWalletConnectProvider(connector!);
    await launchUrlString(provider.connector.session.toUri());
    final cred = WalletConnectEthereumCredentials(provider: provider);
    // EthPrivateKey.fromHex('hex');
    final client = Web3Client(
      'https://polygon-mumbai.g.alchemy.com/v2/jatNf3WknFJWaVVqYftBA_JDrwJS_myg',
      Client(),
    );
    final contract = DeployedContract(
      ContractAbi.fromJson(jsonEncode(abi), 'ChildChainManagerProxy'),
      EthereumAddress.fromHex('0xb5505a6d998549090530911180f38aC5130101c6'),
    );
    final transaction = Transaction.callContract(
        from: await cred.extractAddress(),
        contract: contract,
        function: contract.function('proxyOwner'),
        parameters: [
          // await cred.extractAddress(),
          // BigInt.from(1),
        ]);
    final raw = await client
        .sendTransaction(
      cred,
      transaction,
    )
        .then((value) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(value),
      ));
      return value;
    });
    log(raw);
    // await client.sendRawTransaction(raw);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: account == null
            ? ElevatedButton(
                child: const Text('Connect'),
                onPressed: () {
                  _walletConnect();
                },
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(account!),
                  ElevatedButton(
                    onPressed: () {
                      _approveContract();
                    },
                    child: const Text('Approve Contract'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      _walletDisconnect();
                    },
                    child: const Text('Disconnect'),
                  )
                ],
              ),
      ),
    );
  }

  @override
  void dispose() async {
    super.dispose();
  }
}
