#!/usr/bin/env python3
"""Minimal native GTK Wayland input target for manual wtype acceptance."""

import gi

gi.require_version("Gtk", "4.0")
from gi.repository import Gtk


class App(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="org.codex.GtkInputAcceptance")

    def do_activate(self):
        window = Gtk.ApplicationWindow(application=self)
        window.set_title("GTK Input Acceptance")
        entry = Gtk.Entry()
        entry.set_placeholder_text("Wayland GTK input")
        entry.connect("changed", lambda widget: print(widget.get_text(), flush=True))
        window.set_child(entry)
        window.present()
        entry.grab_focus()


App().run([])
