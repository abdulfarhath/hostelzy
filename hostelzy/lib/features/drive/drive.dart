part of '../../state.dart';

// F29 Part 3 (wave 4): tenant IDs in the owner's own Google Drive. The
// owner connects once (sheet H50 `drive`, from Manage › Tenant IDs); the
// tenant's ID photo then goes from their phone to the owner's Drive through
// the server (`id-upload`), and the owner and managers see it (`id-view`).
// Hostelzy keeps only the Drive file id (DECISIONS 2026-10-18).
mixin _DriveData {
  /// `drive_status` for the hostel in Manage; null until loaded.
  DriveStatus? driveStatus;
  bool driveBusy = false;

  /// Why Drive can't be used yet: `server` (its SQL or functions aren't
  /// there), `scope` (Google's consent screen lacks drive.file, or Google
  /// sign-in isn't set up here); null when it can.
  String? driveUnavailable;

  DriveAuth driveAuth = const NoDriveAuth();
}

extension DriveActions on AppState {
  static const _none = (connected: false, files: 0, fullCopy: false);

  /// Manage › Tenant IDs → H50.
  void openDrive() {
    update(() => sheet = 'drive');
    unawaited(loadDrive());
  }

  Future<void> loadDrive() async {
    final hid = ownHid;
    try {
      final st = await data.driveStatus(hid);
      update(() {
        driveStatus = st ?? _none;
        driveUnavailable = st == null ? 'server' : null;
      });
    } catch (e) {
      debugPrint('drive: $e');
      update(() {
        driveStatus = _none;
        driveUnavailable = 'server';
      });
    }
  }

  /// "Connect Google Drive": Google's consent (drive.file only) → the server
  /// keeps the refresh token encrypted and makes the Tenant IDs folder.
  Future<void> connectDrive() async {
    if (driveBusy || managerHere) return;
    final hid = ownHid;
    update(() => driveBusy = true);
    try {
      var code = 'sample';
      if (data.remote) {
        final (c, fail) = await driveAuth.serverCode();
        if (c == null) {
          if (fail != DriveAuthFail.cancelled) update(() => driveUnavailable = 'scope');
          return;
        }
        code = c;
      }
      final st = await data.driveConnect(hid, code);
      update(() {
        driveStatus = st;
        driveUnavailable = null;
      });
      toastMsg('Google Drive connected');
    } on DriveFail catch (e) {
      debugPrint('drive connect: $e');
      switch (e.code) {
        case 'not_ready':
          update(() => driveUnavailable = 'server');
        case 'no_scope':
          update(() => driveUnavailable = 'scope');
        default:
          toastMsg(e.message);
      }
    } catch (e) {
      debugPrint('drive connect: $e');
      toastMsg('Couldn’t connect');
    } finally {
      update(() => driveBusy = false);
    }
  }

  /// "Disconnect": the server revokes Hostelzy's access at Google and forgets
  /// the token. The files stay in the owner's Drive.
  Future<void> disconnectDrive() async {
    if (driveBusy || managerHere) return;
    final hid = ownHid;
    update(() => driveBusy = true);
    try {
      final st = await data.driveDisconnect(hid);
      update(() => driveStatus = st);
      toastMsg('Disconnected');
    } on DriveFail catch (e) {
      debugPrint('drive disconnect: $e');
      toastMsg(e.code == 'not_ready' ? 'Not available yet' : e.message);
    } catch (e) {
      debugPrint('drive disconnect: $e');
      toastMsg('Couldn’t disconnect');
    } finally {
      update(() => driveBusy = false);
    }
  }

  /// "Full copy needed (police file)": with it on, the tenant's masking bar is off.
  Future<void> toggleFullCopy() async {
    final st = driveStatus;
    if (st == null || !st.connected) return;
    final want = !st.fullCopy;
    update(() => driveStatus = (connected: true, files: st.files, fullCopy: want));
    try {
      await data.setFullCopy(ownHid, want);
    } catch (e) {
      debugPrint('full copy: $e');
      update(() => driveStatus = st);
      toastMsg('Couldn’t save');
    }
  }
}
