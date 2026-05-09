# Copyright 2020-2021 Rafael Mardojai CM
# SPDX-License-Identifier: GPL-3.0-or-later

import os
import platform
from gettext import gettext as _
from urllib.parse import unquote, urlparse

from gi.repository import Adw, Gio, GLib, GObject, Gtk

from blanket.define import RES_PATH, SOUNDS
from blanket.main_player import MainPlayer
from blanket.settings import Settings
from blanket.sound import Sound
from blanket.widgets import PlayPauseButton, PresetChooser, SoundItem, VolumeRow


@Gtk.Template(resource_path=f"{RES_PATH}/window.ui")
class BlanketWindow(Adw.ApplicationWindow):
    __gtype_name__ = "BlanketWindow"

    headerbar: Adw.HeaderBar = Gtk.Template.Child()  # type: ignore
    toast_overlay: Adw.ToastOverlay = Gtk.Template.Child()  # type: ignore
    grid: Gtk.FlowBox = Gtk.Template.Child()  # type: ignore
    playpause_btn: PlayPauseButton = Gtk.Template.Child()  # type: ignore
    volumes: Gtk.Popover = Gtk.Template.Child()  # type: ignore
    volume: Gtk.Scale = Gtk.Template.Child()  # type: ignore
    volume_box: Gtk.Box = Gtk.Template.Child()  # type: ignore
    volume_list: Gtk.ListBox = Gtk.Template.Child()  # type: ignore
    presets_chooser: PresetChooser = Gtk.Template.Child()  # type: ignore
    labels_group: Gtk.SizeGroup = Gtk.Template.Child()  # type: ignore
    power_toast: Adw.Toast = Gtk.Template.Child()  # type: ignore

    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        if platform.system() == "Windows":
            # GTK4 has no set_default_icon(); use Win32 API after window is realized
            self._ico_path = os.path.join(
                os.path.dirname(os.path.dirname(__file__)), "build", "blanket.ico"
            )
            self.connect("realize", self._on_realize_set_win32_icon)
        else:
            self.set_default_icon_name("com.rafaelmardojai.Blanket")

        self.setup_actions()
        # Setup widgets
        self.setup()
        # Setup volume
        self.setup_volume_menu()
        # Populate sounds
        self.populate_sounds()

    def setup(self):
        # Setup grid
        self.sounds_filter = Gtk.CustomFilter.new(
            match_func=self._hide_inactive_sounds_filter
        )
        self.sounds_model = Gtk.FilterListModel.new(
            model=MainPlayer.get(), filter=self.sounds_filter
        )
        self.grid.bind_model(self.sounds_model, self._create_sound_item)
        self.grid.connect("child-activated", self._on_sound_activate)

        # Wire playpause button
        MainPlayer.get().bind_property(
            "playing", self.playpause_btn, "playing", GObject.BindingFlags.SYNC_CREATE
        )

        # Show preset chooser
        self.presets_chooser.props.visible = len(Settings.get().presets) > 1
        Settings.get().connect("changed::presets", self._on_presets_changed)

    def setup_actions(self):
        # Close window action
        action = Gio.SimpleAction.new("close", None)
        action.connect("activate", lambda _action, _param: self.close())
        self.add_action(action)

        # Hide non active sounds
        action = Gio.SimpleAction.new_stateful(
            "hide-inactive",
            None,
            Settings.get()
            .get_preset_settings(Settings.get().active_preset)
            .get_value("hide-inactive"),
        )
        action.connect("change-state", self._on_hide_non_active)
        self.add_action(action)

    def setup_volume_menu(self):
        # Get volume scale adjustment
        vol_adjustment = self.volume.get_adjustment()
        # Bind volume scale value with main player volume
        vol_adjustment.bind_property(
            "value", MainPlayer.get(), "volume", GObject.BindingFlags.BIDIRECTIONAL
        )
        # Set volume scale value on first run
        self.volume.set_value(MainPlayer.get().volume)

        # Setup volume list
        self.volume_filter = Gtk.CustomFilter.new(match_func=lambda item: item.playing)
        model = Gtk.FilterListModel(model=MainPlayer.get(), filter=self.volume_filter)
        model.connect("items-changed", self._volume_model_changed)
        self.volume_box.props.visible = model.get_n_items() > 0
        self.volume_list.bind_model(model, self._create_vol_row)

        # Connect mainplayer preset-changed signal
        MainPlayer.get().connect_after("preset-changed", self._on_preset_changed)
        # Connect mainplayer reset-volumes signal
        MainPlayer.get().connect_after("reset-volumes", self._on_reset_volumes)

        self.volumes.connect("closed", self._volumes_popup_closed)

    def populate_sounds(self):
        """
        Populate default and saved sounds
        """

        # Self populate
        for g in SOUNDS:
            # Iterate sounds
            for s in g["sounds"]:
                # Create a new Sound
                sound = Sound(s["name"], title=s["title"])
                MainPlayer.get().append(sound)

        # Load saved custom audios
        for name, uri in Settings.get().custom_audios.items():
            # Check if file actually exists
            path = unquote(urlparse(uri).path)
            if os.path.exists(path):
                # Create a new Sound
                sound = Sound(name, uri=uri, custom=True)
                MainPlayer.get().append(sound)
            else:
                Settings.get().remove_custom_audio(name)

                alert = Adw.AlertDialog.new(
                    _("Sound Automatically Removed"),
                    _(
                        "The {name} sound is no longer accessible, so it has been removed"
                    ).format(name=f"<b><i>{name}</i></b>"),
                )
                alert.add_response("accept", _("Accept"))
                alert.props.body_use_markup = True
                alert.props.default_response = "accept"
                alert.props.close_response = "accept"
                alert.present(self)

    def open_audio(self):
        def on_response(dialog, result):
            try:
                gfiles = dialog.open_multiple_finish(result)
            except GLib.Error as e:
                if e.code != Gtk.DialogError.DISMISSED:
                    print(f"Error: {e.message}")
                return
            for gfile in gfiles:
                filename = gfile.get_path()
                if filename:
                    basename = os.path.basename(filename)
                    name = basename[: basename.rfind(".")]
                    uri = gfile.get_uri()

                    # Create a new Sound
                    sound = Sound(name, uri=uri, custom=True)
                    # Save to settings
                    GLib.idle_add(
                        Settings.get().add_custom_audio, sound.name, sound.uri
                    )
                    # Add Sound to SoundsGroup
                    MainPlayer.get().append(sound)

        filters = {
            "Supported audio files": [
                "audio/ogg",
                "audio/flac",
                "audio/x-wav",
                "audio/wav",
                "audio/mpeg",
                "audio/aac",
            ],
            "Ogg": ["audio/ogg"],
            "FLAC": ["audio/flac"],
            "WAV": ["audio/x-wav", "audio/wav"],
            "MP3": ["audio/mpeg"],
            "AAC": ["audio/aac"],
        }

        self.filechooser = Gtk.FileDialog.new()
        self.filechooser.set_title(_("Open audio"))
        self.filechooser.set_modal(True)

        filter_store = Gio.ListStore.new(Gtk.FileFilter)
        for f, mts in filters.items():
            audio_filter = Gtk.FileFilter()
            audio_filter.set_name(f)
            for mt in mts:
                audio_filter.add_mime_type(mt)
            filter_store.append(audio_filter)

        self.filechooser.set_filters(filter_store)

        self.filechooser.open_multiple(self, None, on_response)

    @Gtk.Template.Callback()
    def _on_narrow_window_apply(self, _breakpoint):
        if len(Settings.get().presets) > 1:
            self.headerbar.props.show_title = False

    @Gtk.Template.Callback()
    def _on_narrow_window_unapply(self, _breakpoint):
        self.headerbar.props.show_title = True

    def _hide_inactive_sounds_filter(self, item):
        return (
            not Settings.get().get_preset_hide_inactive(Settings.get().active_preset)
            or item.playing
        )

    def _on_hide_non_active(self, action, value: bool):
        action.set_state(value)
        Settings.get().set_preset_hide_inactive(Settings.get().active_preset, value)

        self.__update_filters()

    def _create_vol_row(self, sound):
        row = VolumeRow()

        row.volume = sound.saved_volume
        sound.bind_property(
            "saved_volume", row, "volume", GObject.BindingFlags.BIDIRECTIONAL
        )

        sound.bind_property("title", row, "title", GObject.BindingFlags.SYNC_CREATE)

        return row

    def _create_sound_item(self, sound):
        item = SoundItem()
        # Add label to size group
        self.labels_group.add_widget(item.label)

        if isinstance(sound, Sound):
            # Actual sound items
            item.sound = sound

            sound.bind_property(
                "playing", item, "playing", GObject.BindingFlags.SYNC_CREATE
            )
            sound.bind_property(
                "title", item, "title", GObject.BindingFlags.SYNC_CREATE
            )
            sound.bind_property(
                "icon_name", item, "icon_name", GObject.BindingFlags.SYNC_CREATE
            )
        else:
            # Add new sound item
            item.title = _("Add…")
            item.icon_name = "com.rafaelmardojai.Blanket-add-symbolic"

        return item

    def _on_sound_activate(self, _grid, item):
        # If item sound is None, then it's the Add sound item
        if item.sound is not None:
            # Toggle sound playing state
            item.sound.playing = not item.sound.playing
            # Update volumes list
            self.__update_filters()
        else:
            # Open add sound file chooser
            self.open_audio()

    def _on_presets_changed(self, _settings, _key):
        self.presets_chooser.props.visible = len(Settings.get().presets) > 1

    def _on_preset_changed(self, _player, preset):
        self.__update_filters()

    def _on_reset_volumes(self, _player):
        self.__update_filters()

    def _volume_model_changed(self, model, _pos, _del, _add):
        # Hide volumes list if empty
        self.volume_box.props.visible = model.get_n_items() > 0

    def _volumes_popup_closed(self, _popover):
        # Disable sounds with volume = 0
        MainPlayer.get().mute_vol_zero()
        self.__update_filters()

    def _on_add_sound_clicked(self, _group):
        self.open_audio()

    def __update_filters(self):
        self.sounds_filter.changed(Gtk.FilterChange.DIFFERENT)
        self.volume_filter.changed(Gtk.FilterChange.DIFFERENT)

    def show_power_toast(self):
        self.toast_overlay.add_toast(self.power_toast)

    def hide_power_toast(self):
        self.power_toast.dismiss()

    def _on_realize_set_win32_icon(self, _widget):
        """Set titlebar and taskbar icon via Win32 API (GTK4 has no set_default_icon)."""
        import ctypes
        import ctypes.wintypes

        hwnd = self._get_win32_hwnd()
        if not hwnd:
            return

        LR_LOADFROMFILE = 0x0010
        LR_DEFAULTSIZE  = 0x0040
        IMAGE_ICON      = 1
        WM_SETICON      = 0x0080
        ICON_SMALL      = 0
        ICON_BIG        = 1

        user32   = ctypes.windll.user32
        ico_path = self._ico_path

        # 0,0 + LR_DEFAULTSIZE lets Windows pick the right size from the .ico
        hicon_big = user32.LoadImageW(
            None, ico_path, IMAGE_ICON, 0, 0, LR_LOADFROMFILE | LR_DEFAULTSIZE
        )
        hicon_small = user32.LoadImageW(
            None, ico_path, IMAGE_ICON, 16, 16, LR_LOADFROMFILE
        )

        if hicon_big:
            user32.SendMessageW(hwnd, WM_SETICON, ICON_BIG, hicon_big)
        if hicon_small:
            user32.SendMessageW(hwnd, WM_SETICON, ICON_SMALL, hicon_small)

    def _get_win32_hwnd(self):
        """Return the HWND for this window; tries GdkWin32 then thread enumeration."""
        try:
            from gi.repository import GdkWin32
            return GdkWin32.Win32Surface.get_handle(self.get_surface())
        except Exception:
            pass

        # Fallback: enumerate visible top-level windows on the current thread
        try:
            import ctypes
            import ctypes.wintypes

            user32  = ctypes.windll.user32
            kernel32 = ctypes.windll.kernel32
            tid     = kernel32.GetCurrentThreadId()
            result  = [0]

            WNDENUMPROC = ctypes.WINFUNCTYPE(
                ctypes.c_bool,
                ctypes.wintypes.HWND,
                ctypes.wintypes.LPARAM,
            )

            @WNDENUMPROC
            def _cb(hwnd, _lparam):
                if user32.IsWindowVisible(hwnd):
                    result[0] = hwnd
                    return False
                return True

            user32.EnumThreadWindows(tid, _cb, 0)
            return result[0]
        except Exception:
            return 0
