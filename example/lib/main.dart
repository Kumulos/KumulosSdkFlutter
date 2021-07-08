import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:kumulos_sdk_flutter/kumulos.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runZonedGuarded(() {
    FlutterError.onError = Kumulos.onFlutterError;

    runApp(MyApp());
  }, Kumulos.logUncaughtError);
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: HomePage());
  }
}

class HomePage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _HomePageState();
  }
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();

    Kumulos.setEventHandlers(pushReceivedHandler: (push) {
      _showAlert('Received Push', <Widget>[
        Text(push.title ?? 'No title'),
        Text(push.message ?? 'No message'),
      ]);
    }, pushOpenedHandler: (push) {
      _showAlert('Opened Push', <Widget>[
        Text(push.title ?? 'No title'),
        Text(push.message ?? 'No message'),
        Text(''),
        Text('Action button tapped: ${push.actionId ?? 'none'}'),
        Text('Data:'),
        Text(jsonEncode(push.data))
      ]);
    }, inAppDeepLinkHandler: (data) {
      _showAlert(
          'In-App Message Button Press', <Widget>[Text(data.toString())]);
    }, deepLinkHandler: (outcome) {
      var children = [
        Text('Url: ${outcome.url}'),
        Text('Resolved: ${outcome.resolution}')
      ];

      if (outcome.resolution == KumulosDeepLinkResolution.LinkMatched) {
        children.addAll([
          Text('Link title: ${outcome.content?.title}'),
          Text('Link description: ${outcome.content?.description}'),
          Text('Link data:'),
          Text(jsonEncode(outcome.linkData))
        ]);
      }

      _showAlert('Kumulos Deep Link', children);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: SingleChildScrollView(
            child: SafeArea(
                child: Container(
          margin: EdgeInsets.only(left: 20, right: 20, top: 10),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                    onPressed: () async {
                      var installId = await Kumulos.installId;
                      _showAlert('Install ID', <Widget>[Text(installId)]);
                    },
                    child: Text('Install ID')),
                Text('User Operations'),
                ElevatedButton(
                    onPressed: () async {
                      var currentUserId = await Kumulos.currentUserIdentifier;
                      _showAlert('User Identifier', <Widget>[
                        Text('''
Currently identified as:

$currentUserId

If no user is currently associated, this will be the install ID.''')
                      ]);
                    },
                    child: Text('Current user identifier')),
                ElevatedButton(
                    onPressed: () async {
                      await Kumulos.associateUserWithInstall(
                          identifier: 'Robot',
                          attributes: {'batteryLevel': 96});
                      var currentUserId = await Kumulos.currentUserIdentifier;
                      _showAlert('User Identifier', <Widget>[
                        Text('''
Changed associated user to:

$currentUserId''')
                      ]);
                    },
                    child: Text('Associate as user "Robot"')),
                ElevatedButton(
                    onPressed: () async {
                      await Kumulos.clearUserAssociation();
                      var currentUserId = await Kumulos.currentUserIdentifier;
                      _showAlert('User Identifier', <Widget>[
                        Text('''
Changed associated user to:

$currentUserId

(this is the install ID)'''),
                      ]);
                    },
                    child: Text('Clear associated user')),
                Text('Events'),
                ElevatedButton(
                    onPressed: () async {
                      Kumulos.trackEvent(
                          eventType: 'product.purchased',
                          properties: {'productSku': 'example'});
                      _showAlert('Tracked Event', <Widget>[
                        Text(
                            'The event was tracked locally and queued for batched sending to the server later.')
                      ]);
                    },
                    child: Text('Track "product.purchased" event')),
                ElevatedButton(
                    onPressed: () async {
                      Kumulos.trackEventImmediately(
                          eventType: 'product.purchased',
                          properties: {'productSku': 'example'});
                      _showAlert('Tracked Event', <Widget>[
                        Text('The event was tracked and sent to the server.')
                      ]);
                    },
                    child: Text('Track "product.purchased" immediately')),
                Text('Push'),
                ElevatedButton(
                    onPressed: () async {
                      Kumulos.pushRequestDeviceToken();
                    },
                    child: Text('Request push token')),
                ElevatedButton(
                    onPressed: () async {
                      Kumulos.pushUnregister();
                    },
                    child: Text('Unregister from push')),
                ElevatedButton(
                    onPressed: () async {
                      var mgr = await Kumulos.pushChannelManager;
                      var channels = await mgr.listChannels();
                      var list = channels
                          .map((c) => Text(
                              '${c.uuid} ${c.name} ${c.isSubscribed ? '(subscibed)' : ''}'))
                          .toList();
                      _showAlert('Channels', list);
                    },
                    child: Text('List channels')),
                ElevatedButton(
                    onPressed: () async {
                      var mgr = await Kumulos.pushChannelManager;
                      await mgr.clearSubscriptions();
                      _showAlert('Channels', [Text('Cleared subscriptions')]);
                    },
                    child: Text('Clear subscriptions')),
                ElevatedButton(
                    onPressed: () async {
                      var mgr = await Kumulos.pushChannelManager;
                      await mgr.setSubscriptions(['dinosaurs', 'ninjas']);
                      _showAlert('Channels', [Text('Set subscriptions')]);
                    },
                    child: Text('Set subscriptions')),
                ElevatedButton(
                    onPressed: () async {
                      var mgr = await Kumulos.pushChannelManager;
                      await mgr.subscribe(['ninjas']);
                      _showAlert('Channels', [Text('Subscribed to "ninjas"')]);
                    },
                    child: Text('Subscribe "ninjas"')),
                ElevatedButton(
                    onPressed: () async {
                      var mgr = await Kumulos.pushChannelManager;
                      await mgr.unsubscribe(['dinosaurs']);
                      _showAlert(
                          'Channels', [Text('Unsubscribed from "dinosaurs"')]);
                    },
                    child: Text('Unsubscribe "dinosaurs"')),
                ElevatedButton(
                    onPressed: () async {
                      var mgr = await Kumulos.pushChannelManager;
                      var channel = await mgr.createChannel(
                          uuid: 'vikings',
                          name: 'Vikings',
                          showInPortal: true,
                          subscribe: true,
                          meta: {'sea_skill': 8});
                      _showAlert('Channels', [Text('Created ${channel.name}')]);
                    },
                    child: Text('Create "vikings"')),
                Text('In App'),
                ElevatedButton(
                    onPressed: () async {
                      Navigator.push(context,
                          MaterialPageRoute(builder: (context) => Inbox()));
                    },
                    child: Text('Inbox')),
                ElevatedButton(
                    onPressed: () async {
                      var summary = await KumulosInApp.getInboxSummary();
                      _showAlert('In-app inbox summary', [
                        Text(
                            'Total: ${summary?.totalCount} Unread: ${summary?.unreadCount}')
                      ]);
                    },
                    child: Text('In-app inbox summary')),
                ElevatedButton(
                    onPressed: () async {
                      await KumulosInApp.updateConsentForUser(true);
                      _showAlert('In-app consent',
                          [Text('Opted in to in-app messaging')]);
                    },
                    child: Text('Opt in')),
                ElevatedButton(
                    onPressed: () async {
                      await KumulosInApp.updateConsentForUser(false);
                      _showAlert('In-app consent',
                          [Text('Opted out from in-app messaging')]);
                    },
                    child: Text('Opt out')),
                Text('Location'),
                ElevatedButton(
                    onPressed: () async {
                      Kumulos.sendLocationUpdate(latitude: 0, longitude: 0);
                      _showAlert('Tracked Event',
                          <Widget>[Text('Sent location update.')]);
                    },
                    child: Text('Send location (0,0)')),
                Text('Crash'),
                ElevatedButton(
                    onPressed: () {
                      throw "Oops, an unexpected error happened";
                    },
                    child: Text('Throw an unexpected error')),
                ElevatedButton(
                    onPressed: () {
                      Kumulos.logError(
                          "We knew about this one", StackTrace.current);
                    },
                    child: Text('Record expected error')),
                Text('Backend'),
                ElevatedButton(
                    onPressed: () async {
                      var client = await Kumulos.backendRpcClient;
                      // This is an example method call and will not work if not defined
                      // on your Kumulos app.
                      //
                      // For further information on using the Backend features of Kumulos,
                      // please refer to the documentation at https://docs.kumulos.com
                      var result = await client.call(
                          methodAlias: 'getUserProfile',
                          params: {'username': 'kumulos'});

                      _showAlert('Called API Method', [
                        Text('Response code: ${result.responseCode}'),
                        Text('Payload:'),
                        Text(jsonEncode(result.payload))
                      ]);
                    },
                    child: Text('Call an API')),
              ]),
        ))));
  }

  void _showAlert(String title, List<Widget> children) {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
              child: ListBody(
                children: children,
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        });
  }
}

class Inbox extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _InboxState();
  }
}

class _InboxState extends State<Inbox> {
  List<KumulosInAppInboxItem> items = [];
  KumulosInAppInboxSummary? summary;
  Object? error;

  @override
  void initState() {
    super.initState();

    KumulosInApp.setOnInboxUpdatedHandler(() {
      _loadState();
    });

    _loadState();
  }

  @override
  void dispose() {
    super.dispose();
    KumulosInApp.setOnInboxUpdatedHandler(null);
  }

  @override
  Widget build(BuildContext context) {
    var content;

    if (null != error) {
      content = Container(
          margin: EdgeInsets.all(8),
          child: Center(child: Text(error.toString())));
    } else if (null == summary) {
      content = Container(
          child: Center(child: CircularProgressIndicator(value: null)));
    } else {
      content = _renderInbox();
    }

    return Scaffold(
        appBar: AppBar(
          title: Text('In-app inbox'),
          actions: [
            IconButton(
                tooltip: 'Mark all read',
                onPressed: () {
                  KumulosInApp.markAllInboxItemsAsRead();
                },
                icon: Icon(Icons.mark_email_read)),
          ],
        ),
        body: SafeArea(
          child: content,
        ));
  }

  _loadState() async {
    try {
      var items = await KumulosInApp.getInboxItems();
      var summary = await KumulosInApp.getInboxSummary();

      setState(() {
        this.items = items;
        this.summary = summary;
        error = null;
      });
    } on PlatformException catch (e) {
      // Typically this exception would only happen when the in-app strategy
      // is set to explicit-by-user and consent management is being done
      // manually.
      setState(() {
        this.error = e.message;
      });
    }
  }

  Widget _renderInbox() {
    if (items.length == 0) {
      return Center(
        child: Text('No items'),
      );
    }

    return Column(children: [
      Expanded(
          child: ListView.separated(
              itemBuilder: (ctx, idx) => _renderItem(items[idx]),
              separatorBuilder: (ctx, idx) => Divider(),
              itemCount: items.length)),
      Container(
        margin: EdgeInsets.all(8),
        child: Text(
            'Total: ${summary?.totalCount} Unread: ${summary?.unreadCount}'),
      ),
    ]);
  }

  Widget _renderItem(KumulosInAppInboxItem item) {
    return ListTile(
      key: Key(item.id.toString()),
      title: Text(item.title),
      subtitle: Text(item.subtitle),
      leading: Icon(
        Icons.label_important,
        color: item.isRead
            ? Theme.of(context).disabledColor
            : Theme.of(context).indicatorColor,
      ),
      trailing: item.imageUrl != null
          ? CircleAvatar(
              backgroundColor: Colors.grey.shade400,
              backgroundImage: NetworkImage(item.imageUrl!),
            )
          : null,
      onTap: () {
        KumulosInApp.presentInboxMessage(item);
      },
      onLongPress: () {
        showModalBottomSheet(
            context: context,
            builder: (context) {
              return SafeArea(
                  child: Wrap(
                children: [
                  ListTile(
                    leading: Icon(Icons.mark_email_read),
                    title: Text(
                      'Mark as read',
                    ),
                    onTap: () {
                      KumulosInApp.markAsRead(item);
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.delete),
                    title: Text(
                      'Delete from inbox',
                    ),
                    onTap: () {
                      KumulosInApp.deleteMessageFromInbox(item);
                      Navigator.pop(context);
                    },
                  )
                ],
              ));
            });
      },
    );
  }
}
