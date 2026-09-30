import QtQuick
import Quickshell
import "plugin" as Plugin
import "plugin/Calendar.js" as Cal

ShellRoot {
  id: root
  property bool submitted: false
  Plugin.BarWidget {
    id: widget
    settings: ({ backend: "google", googleAccount: "calendar@example.test", notifications: false })
    onWriteFinished: function(ok, message) {
      if (!ok) throw new Error("Fixture write failed: " + message)
      quickAdd.submit({title: "Fixture write", date: "2026-09-28", allDay: true,
                       calendarId: "calendar@example.test"})
    }
  }
  Plugin.QuickAdd {
    id: quickAdd
    shell: QtObject {
      property var barConfig: ({ layout: { center: [{ id: "crmne.omacal", backend: "google", googleAccount: "calendar@example.test" }] } })
      function hide(id) {
        if (quickAdd.error !== "" || quickAdd.busy) throw new Error("Quick-add write did not finish")
        console.log("OMACAL_QML_SMOKE_OK")
        Qt.quit()
      }
    }
  }
  Plugin.QuickAdd { id: heyQuickAdd }
  Plugin.SettingsView {
    id: settingsPanel
    host: widget
    panel: QtObject {
      function setting(key, fallback) { return widget.setting(key, fallback) }
      function persistSettings(values) {
        var next = Object.assign({}, widget.settings, values)
        widget.settings = next
      }
    }
  }
  function findToggle(item) {
    if (item.label === "Today only") return item
    var children = item.children || []
    for (var i = 0; i < children.length; i++) {
      var found = findToggle(children[i])
      if (found) return found
    }
    return null
  }
  function testTodayToggle() {
    widget.displayDate = new Date(2026, 8, 29, 11, 42)
    var meeting = Cal.normalizeEvent({id: 101, title: "Today meeting",
      starts_at: new Date(2026, 8, 29, 13).toISOString(), ends_at: new Date(2026, 8, 29, 14).toISOString()})
    var birthday = Cal.normalizeEvent({id: 102, title: "Future birthday", all_day: true,
      starts_at: "2026-10-02", ends_at: "2026-10-03", reminders: [new Date(2026, 8, 25, 9).toISOString()]})
    widget.weekCache = ({ "2026-09-28": { events: [birthday, meeting], at: Date.now() } })
    widget.rebuildIndex()
    var toggle = findToggle(settingsPanel)
    if (!toggle || toggle.checked) throw new Error("Today-only must default off")
    if (widget.shownEvents[0].title !== "Future birthday") throw new Error("Original mode failed")
    toggle.clicked()
    if (!toggle.checked || widget.settings.todayOnly !== true) throw new Error("Toggle was not saved")
    if (widget.shownEvents[0].title !== "Today meeting") throw new Error("Today-only binding failed")
    toggle.clicked()
    if (toggle.checked || widget.settings.todayOnly !== false) throw new Error("Toggle off was not saved")
    if (widget.shownEvents[0].title !== "Future birthday") throw new Error("Original behavior was not restored")
  }
  Plugin.EventForm {
    id: form
    calendars: widget.writableCalendars
    defaultCalendarId: "calendar@example.test"
  }
  Timer {
    interval: 100
    running: true
    repeat: true
    onTriggered: {
      if (!widget.loaded || widget.calendars.length === 0 || root.submitted) return
      if (widget.lastError !== "") throw new Error(widget.lastError)
      if (widget.events.length === 0) throw new Error("No fixture events")
      if (widget.events[0].calendarId !== "calendar@example.test") throw new Error("Lost calendar ID")
      if (form.calendarId !== "calendar@example.test") throw new Error("Form lost calendar ID")
      if (quickAdd.backend.info.id !== "google") throw new Error("Quick add uses wrong backend")
      if (heyQuickAdd.backend.info.id !== "hey") throw new Error("Default HEY backend changed")
      if (widget.capabilities.watch || widget.capabilities.timeTracking) throw new Error("Wrong capabilities")
      root.submitted = true
      root.testTodayToggle()
      if (!widget.addEvent({title: "Fixture write", date: "2026-09-28", allDay: true,
                           calendarId: form.calendarId})) throw new Error("Write did not start")
    }
  }
}
