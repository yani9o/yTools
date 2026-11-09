-- Edit each term's enUS and deDE text below. Other client locales use English.
-- Keep internal IDs, commands and saved values out of translated UI text.
local _, addon = ...
local terms = {
    ["LEYLINES_MODULE"] = { enUS = "UI > Leylines", deDE = "UI > Leylinien" },
    ["LEYLINES_DESCRIPTION"] = { enUS = "Marks possible leyline locations on zone maps.", deDE = "Markiert mögliche Leylinien-Fundorte auf Gebietskarten." },
    ["BLOCKED_ACTION_TRACE"] = { enUS = "Blocked action trace (%s):\n%s", deDE = "Aufrufpfad der blockierten Aktion (%s):\n%s" },
    ["SETTINGS_AFTER_COMBAT"] = { enUS = "Settings will open after combat.", deDE = "Die Einstellungen werden nach dem Kampf geöffnet." },
    ["LIBRARY_BOOKS_MODULE"] = { enUS = "UI > Library Books     /ytools librarybooks", deDE = "UI > Bibliotheksbücher     /ytools librarybooks" },
    ["LIBRARY_BOOKS_TITLE"] = { enUS = "Library Books", deDE = "Bibliotheksbücher" },
    ["LIBRARY_BOOKS_DESCRIPTION"] = { enUS = "Marks 38 known library books on zone and continent maps. Gold: not turned in. Blue: in your bags or bank. Green check: turned in. Completed quests are checked automatically, including earlier deliveries. Hover for location hints.", deDE = "Markiert 38 bekannte Bibliotheksbücher auf Gebiets- und Kontinentkarten. Gold: noch nicht abgegeben. Blau: in deinen Taschen oder deiner Bank. Grüner Haken: abgegeben. Abgeschlossene Quests werden automatisch geprüft, auch frühere Abgaben. Fundorthinweise beim Darüberfahren." },
    ["LIBRARY_BOOKS_DONE"] = { enUS = "Turned in", deDE = "Bereits abgegeben" },
    ["LIBRARY_BOOKS_BANK"] = { enUS = "In your bank – not turned in", deDE = "In deiner Bank – noch nicht abgegeben" },
    ["LIBRARY_BOOKS_CARRIED"] = { enUS = "In your bags — ready to turn in", deDE = "In deinen Taschen – noch nicht abgegeben" },
    ["LIBRARY_BOOKS_MISSING"] = { enUS = "Not turned in", deDE = "Noch nicht abgegeben" },
    ["LIBRARY_BOOKS_UNCONFIRMED"] = { enUS = "Location not yet confirmed in Forever.", deDE = "Fundort in Forever noch nicht bestätigt." },
    ["LIBRARY_BOOKS_PIN_HINT"] = { enUS = "Left-click: set waypoint. Right-click: open zone map.", deDE = "Linksklick: Wegpunkt setzen. Rechtsklick: Gebietskarte öffnen." },
    ["LIBRARY_BOOKS_HIDE"] = { enUS = "Hide turned-in books", deDE = "Bereits abgegebene Bücher ausblenden" },
    ["LIBRARY_BOOKS_PROGRESS"] = { enUS = "%d/%d books turned in · %d in your bags · %d in your bank", deDE = "%d/%d Bücher abgegeben · %d in deinen Taschen · %d in deiner Bank" },
    ["LIBRARY_BOOKS_COMMAND"] = { enUS = "Show library book progress. Add hide/show to hide/show turned-in map markers.", deDE = "Zeigt den Bücherfortschritt. Mit hide/show blendest du abgegebene Bücher auf der Karte aus/ein." },
    ["TARGET_THREAT_DEBUG_ON"] = { enUS = "Threat debug enabled. Reproduce the 100% display and copy the Threat messages.", deDE = "Bedrohungs-Debug aktiviert. Stelle die 100-%-Anzeige nach und kopiere die Threat-Meldungen." },
    ["TARGET_THREAT_DEBUG_OFF"] = { enUS = "Threat debug disabled.", deDE = "Bedrohungs-Debug deaktiviert." },
    ["TARGET_THREAT_DEBUG_HELP"] = { enUS = "Use /ytools targetthreat debug to toggle threat diagnostics.", deDE = "Mit /ytools targetthreat debug schaltest du die Bedrohungs-Diagnose um." },
    ["PET_SKILLS_FAMILY_SKILLS"] = { enUS = "Family Skills", deDE = "Familienfähigkeiten" },
    ["PET_SKILLS_PASSIVES"] = { enUS = "Passives", deDE = "Passive Fähigkeiten" },
    ["PET_SKILLS_RANK_ROW"] = { enUS = "%d – %s (Rank %d)", deDE = "%d – %s (Rang %d)" },
    ["PET_SKILLS_MODULE"] = { enUS = "Utility > Pet Skills     /ytools petskills", deDE = "Werkzeuge > Tierfähigkeiten     /ytools petskills" },
    ["PET_SKILLS_TITLE"] = { enUS = "Pet Skills", deDE = "Tierfähigkeiten" },
    ["PET_SKILLS_DESCRIPTION"] = { enUS = "Browse hunter pet abilities, ranks and where to learn them.", deDE = "Zeigt Jäger-Tierfähigkeiten, ihre Ränge und wo du sie lernen kannst." },
    ["PET_SKILLS_RANK"] = { enUS = "Rank %d", deDE = "Rang %d" },
    ["PET_SKILLS_REQUIREMENTS"] = { enUS = "Pet level: %d\nTraining points: %d", deDE = "Tierstufe: %d\nAusbildungspunkte: %d" },
    ["PET_SKILLS_FAMILIES"] = { enUS = "Pet families", deDE = "Tierfamilien" },
    ["PET_SKILLS_ALL_FAMILIES"] = { enUS = "All families", deDE = "Alle Familien" },
    ["PET_SKILLS_SOURCES"] = { enUS = "Where to learn", deDE = "Hier lernen" },
    ["PET_SKILLS_TRAINER"] = { enUS = "Pet trainer", deDE = "Tierausbilder" },
    ["PET_SKILLS_BEAST_LEVEL"] = { enUS = "Beast level: %s", deDE = "Tierstufe: %s" },
    ["PET_SKILLS_NO_SOURCE"] = { enUS = "No source is known for this rank yet.", deDE = "Für diesen Rang ist bisher keine Quelle bekannt." },
    ["PET_SKILLS_UNKNOWN_ZONE"] = { enUS = "Location unknown", deDE = "Fundort unbekannt" },
    ["PET_SKILLS_UNKNOWN_LEVEL"] = { enUS = "Unknown", deDE = "Unbekannt" },
    ["PET_SKILLS_OPEN_MAP"] = { enUS = "Show known location on the map", deDE = "Bekannten Fundort auf der Karte anzeigen" },
    ["PET_SKILLS_DATA_NOTE"] = { enUS = "Tame the beast and let it use the skill to learn it. Community data may be incomplete.", deDE = "Zähme das Tier und lass es die Fähigkeit benutzen, um sie zu lernen. Community-Daten können unvollständig sein." },
    ["PET_SKILLS_SEARCH"] = { enUS = "Search skills or ranks…", deDE = "Fähigkeit oder Rang suchen…" },
    ["PET_SKILLS_NO_RESULTS"] = { enUS = "No matching skills.", deDE = "Keine passenden Fähigkeiten." },
    ["PET_SKILLS_COMBAT"] = { enUS = "Open Pet Skills after combat.", deDE = "Öffne die Tierfähigkeiten nach dem Kampf." },
    ["PET_SKILLS_COMMAND"] = { enUS = "Open the Pet Skills spellbook tab.", deDE = "Öffnet den Tierfähigkeiten-Reiter im Zauberbuch." },
    ["PET_FAMILY_BAT"] = { enUS = "Bat", deDE = "Fledermaus" },
    ["PET_FAMILY_BEAR"] = { enUS = "Bear", deDE = "Bär" },
    ["PET_FAMILY_BIRD_OF_PREY"] = { enUS = "Bird of Prey", deDE = "Greifvogel" },
    ["PET_FAMILY_BOAR"] = { enUS = "Boar", deDE = "Eber" },
    ["PET_FAMILY_CARRION_BIRD"] = { enUS = "Carrion Bird", deDE = "Aasvogel" },
    ["PET_FAMILY_CAT"] = { enUS = "Cat", deDE = "Katze" },
    ["PET_FAMILY_CRAB"] = { enUS = "Crab", deDE = "Krebs" },
    ["PET_FAMILY_CROCOLISK"] = { enUS = "Crocolisk", deDE = "Krokilisk" },
    ["PET_FAMILY_FOX"] = { enUS = "Fox", deDE = "Fuchs" },
    ["PET_FAMILY_GORILLA"] = { enUS = "Gorilla", deDE = "Gorilla" },
    ["PET_FAMILY_HYENA"] = { enUS = "Hyena", deDE = "Hyäne" },
    ["PET_FAMILY_RAPTOR"] = { enUS = "Raptor", deDE = "Raptor" },
    ["PET_FAMILY_SCORPID"] = { enUS = "Scorpid", deDE = "Skorpid" },
    ["PET_FAMILY_SPIDER"] = { enUS = "Spider", deDE = "Spinne" },
    ["PET_FAMILY_TALLSTRIDER"] = { enUS = "Tallstrider", deDE = "Ebenenschreiter" },
    ["PET_FAMILY_TURTLE"] = { enUS = "Turtle", deDE = "Schildkröte" },
    ["PET_FAMILY_WIND_SERPENT"] = { enUS = "Wind Serpent", deDE = "Windnatter" },
    ["PET_FAMILY_WOLF"] = { enUS = "Wolf", deDE = "Wolf" },

    ["LEARN_ALL_MODULE"] = { enUS = "Automation > Learn All", deDE = "Automatisierung > Alles lernen" },
    ["LEARN_ALL_DESCRIPTION"] = { enUS = "Adds Learn All to class, profession and weapon trainers. Hover for the total cost.", deDE = "Fügt Klassen-, Berufs- und Waffenlehrern Alles lernen hinzu. Gesamtkosten beim Darüberfahren." },
    ["LEARN_ALL_TOOLTIP_TITLE"] = { enUS = "Learn All", deDE = "Alles lernen" },
    ["LEARN_ALL_BUTTON"] = { enUS = "All", deDE = "Alle" },
    ["LEARN_ALL_WORKING"] = { enUS = "Learning…", deDE = "Lernt…" },
    ["LEARN_ALL_POINTS"] = { enUS = "%d training points", deDE = "%d Ausbildungspunkte" },
    ["LEARN_ALL_COUNT"] = { enUS = "%d available skills — total:", deDE = "%d verfügbare Fähigkeiten — gesamt:" },
    ["LEARN_ALL_HINT"] = { enUS = "One click learns available skills automatically. New primary professions keep their normal confirmation.", deDE = "Lernt verfügbare Fähigkeiten mit einem Klick automatisch. Neue Hauptberufe behalten ihre normale Bestätigung." },
    ["LEARN_ALL_COMMAND"] = { enUS = "Learn all available skills at the open trainer.", deDE = "Lernt alle verfügbaren Fähigkeiten beim geöffneten Lehrer." },
    ["MAP_REVEAL_MODULE"] = { enUS = "UI > Reveal Maps", deDE = "UI > Karten aufdecken" },
    ["MAP_REVEAL_DESCRIPTION"] = { enUS = "Shows unexplored map areas with a 50% grey overlay. Explored areas remain unchanged.", deDE = "Zeigt unentdeckte Kartenbereiche mit einer 50 % grauen Überlagerung. Entdeckte Bereiche bleiben unverändert." },
    ["MAP_REVEAL_COMMAND"] = { enUS = "Toggle unexplored map areas.", deDE = "Schaltet die Anzeige unentdeckter Kartenbereiche um." },
    ["TOOLS_CLASS_TRAINER"] = { enUS = "Utility > ClassTrainer     /ytools classtrainer", deDE = "Werkzeuge > Klassenlehrer     /ytools classtrainer" },
    ["CLASS_TRAINER"] = { enUS = "ClassTrainer", deDE = "Klassenlehrer" },
    ["CLASS_TRAINER_DESCRIPTION"] = {
        enUS = "Shows spells and their costs from your class trainer in the spellbook.",
        deDE = "Zeigt Zauber und ihre Kosten beim Klassenlehrer im Zauberbuch." },
    ["CLASS_TRAINER_VISIT"] = {
        enUS = "Visit a class trainer to save the available spells and their costs.",
        deDE = "Besuche einen Klassenlehrer, um die angebotenen Zauber und ihre Kosten zu speichern." },
    ["CLASS_TRAINER_COMMAND_HELP"] = { enUS = "Open Trainer Spells. Add reset to clear saved trainer data.", deDE = "Öffnet die Lehrerzauber. Mit reset löschst du die gespeicherten Lehrerdaten." },
    ["CLASS_TRAINER_RESET_DONE"] = { enUS = "Trainer data cleared. Visit a class trainer to rebuild the list.", deDE = "Lehrerdaten gelöscht. Besuche einen Klassenlehrer, um die Liste neu zu füllen." },
    ["CLASS_TRAINER_OPEN_FAILED"] = { enUS = "Couldn't open the Spellbook. Open it and click the ClassTrainer tab.", deDE = "Das Zauberbuch konnte nicht geöffnet werden. Öffne es und klicke auf den Klassenlehrer-Reiter." },
    ["CLASS_TRAINER_EMPTY"] = { enUS = "No trainer spells saved.", deDE = "Keine Lehrerzauber gespeichert." },
    ["CLASS_TRAINER_LEVEL"] = { enUS = "Requires level %d", deDE = "Benötigt Stufe %d" },
    ["CLASS_TRAINER_TOTAL_COST"] = { enUS = "Total cost:", deDE = "Gesamtkosten:" },
    ["CLASS_TRAINER_COST"] = { enUS = "Cost:", deDE = "Kosten:" },
    ["CLASS_TRAINER_LEARNED"] = { enUS = "Already learned", deDE = "Bereits erlernt" },
    ["CLASS_TRAINER_AVAILABLE"] = { enUS = "Available", deDE = "Verfügbar" },
    ["CLASS_TRAINER_UNAVAILABLE"] = { enUS = "Requirements not met", deDE = "Voraussetzungen nicht erfüllt" },
    ["CLASS_TRAINER_SNAPSHOT"] = { enUS = "Last trainer visited: %s.\nCosts reflect that visit.", deDE = "Zuletzt besuchter Lehrer: %s.\nKosten entsprechen diesem Besuch." },
    ["TOOLTIP_QUEST_IDS"] = { enUS = "Tooltip > Quest IDs", deDE = "Tooltip > Quest-IDs" },
    ["TOOLTIP_QUEST_IDS_DESCRIPTION"] = { enUS = "Shows quest IDs in quest tooltips.", deDE = "Zeigt Quest-IDs in Quest-Tooltips." },
    ["QUEST_ID"] = { enUS = "Quest ID:", deDE = "Quest-ID:" },
    ["BAG_SLOTS_OPTIONS"] = { enUS = "Bag Slots", deDE = "Taschenplätze" },
    ["BAG_SLOTS_COMMAND_HELP"] = { enUS = "Opens the bag slot options.", deDE = "Öffnet die Optionen für Taschenplätze." },
    ["ENABLE_BAG_SLOTS"] = { enUS = "Enable bag slot layout", deDE = "Taschenplatz-Anordnung aktivieren" },
    ["REVERSE_BAG_SLOTS"] = { enUS = "Reverse slots", deDE = "Taschenplätze umkehren" },
    ["BAG_SLOTS_SEPARATE_AMMO"] = { enUS = "Quiver and ammo pouch on a separate row", deDE = "Köcher und Munitionsbeutel in eigener Zeile" },
    ["PLAYERBORDER_OPTIONS_COMMAND_HELP"] = { enUS = "show options UI", deDE = "Optionen öffnen" },
    ["CHARACTERSTATS_COMMAND_HELP"] = { enUS = "Opens the character stats options.", deDE = "Öffnet die Optionen für Charakterwerte." },
    ["FISHING_COMMAND_HELP"] = { enUS = "Opens the fishing helper options.", deDE = "Öffnet die Optionen für die Angelhilfe." },
    ["UI_CHARACTER_INFO_PANEL"] = { enUS = "UI > Always show Infopanel", deDE = "UI > Infopanel immer anzeigen" },
    ["CHARACTER_INFO_PANEL_DESCRIPTION"] = {
        enUS = "Keeps the infopanel expanded on all character window tabs.",
        deDE = "Hält das Infopanel auf allen Tabs des Charakterfensters geöffnet.",
    },
    ["UI_CHARACTERSTATS"] = { enUS = "UI > Characterstats     /ytools charstats", deDE = "UI > Charakterwerte     /ytools charstats" },
    ["CHARACTERSTATS_OPTIONS"] = { enUS = "Characterstats", deDE = "Charakterwerte" },
    ["CHARACTERSTATS_DESCRIPTION"] = {
        enUS = "Allows you to reorder and hide character stats.",
        deDE = "Erlaubt das Sortieren und Ausblenden von Charakterwerten.",
    },
    ["CHARACTERSTATS_HINT"] = {
        enUS = "Use the arrows to change the order and the checkboxes to show or hide sections and stats. Saved per character.",
        deDE = "Ändere die Reihenfolge mit den Pfeilen und blende Bereiche und Werte mit den Kontrollkästchen ein oder aus. Wird pro Charakter gespeichert.",
    },
    ["CHARACTERSTATS_ENABLE"] = { enUS = "Enable", deDE = "Aktivieren" },
    ["CHARACTERSTATS_RESET"] = { enUS = "Reset order and visibility", deDE = "Reihenfolge und Sichtbarkeit zurücksetzen" },
    ["CHARACTERSTATS_UP"] = { enUS = "Move up", deDE = "Nach oben" },
    ["CHARACTERSTATS_DOWN"] = { enUS = "Move down", deDE = "Nach unten" },
    ["TOOLTIP_ITEM_COUNT"] = {
        enUS = "Tooltip > Bag/Bank Counter     /ytools itemcount",
        deDE = "Tooltip > Taschen-/Bankzähler     /ytools itemcount",
    },
    ["TOOLTIP_ITEM_COUNT_DESCRIPTION"] = {
        enUS = "Shows the number of this item owned by your characters.",
        deDE = "Zeigt die Anzahl des Gegenstands im Besitz deiner Charaktere.",
    },
    ["ITEM_COUNT_COMMAND_HELP"] = {
        enUS = "Show item counter commands",
        deDE = "Gegenstandszähler-Befehle anzeigen",
    },
    ["ITEM_COUNT_DELETE_HELP"] = {
        enUS = "/ytools itemcount delete <first name> <last name> - Delete this character's saved item data.",
        deDE = "/ytools itemcount delete <Vorname> <Nachname> - Gespeicherte Gegenstandsdaten dieses Charakters löschen.",
    },
    ["ITEM_COUNT_DELETED"] = {
        enUS = "Saved item data for %s deleted.",
        deDE = "Gespeicherte Gegenstandsdaten für %s gelöscht.",
    },
    ["ITEM_COUNT_NOT_FOUND"] = {
        enUS = "No saved item data found for %s on this realm.",
        deDE = "Keine gespeicherten Gegenstandsdaten für %s auf diesem Realm gefunden.",
    },
    ["ITEM_COUNT_BAGS"] = { enUS = "Bags", deDE = "Taschen" },
    ["ITEM_COUNT_BANK"] = { enUS = "Bank", deDE = "Bank" },
    ["ITEM_COUNT_EQUIPPED"] = { enUS = "Equipped", deDE = "Angelegt" },
    ["ITEM_COUNT_TOTAL"] = { enUS = "Total:", deDE = "Gesamt:" },
    ["TOOLTIP_ITEM_LEVEL"] = {
        enUS = "Tooltip > Item Level",
        deDE = "Tooltip > Gegenstandsstufe",
    },
    ["TOOLTIP_ITEM_LEVEL_DESCRIPTION"] = {
        enUS = "Shows item levels in item and comparison tooltips.",
        deDE = "Zeigt die Gegenstandsstufe in Gegenstands- und Vergleichstooltips.",
    },
    ["ITEM_LEVEL_LABEL"] = {
        enUS = "Item level:",
        deDE = "Gegenstandsstufe:",
    },
    ["CHAT_COPY_LINKS"] = {
        enUS = "Chat > Copy Links",
        deDE = "Chat > Links kopieren",
    },
    ["CHAT_COPY_LINKS_DESCRIPTION"] = {
        enUS = "Makes web links in chat clickable.",
        deDE = "Macht Web-Links im Chat anklickbar.",
    },
    ["COPY_LINK"] = {
        enUS = "Copy link",
        deDE = "Link kopieren",
    },
    ["COPY_LINK_HINT"] = {
        enUS = "Press Ctrl+C to copy the link. Escape closes this window.",
        deDE = "Drücke Strg+C, um den Link zu kopieren. Escape schließt dieses Fenster.",
    },
    ["NOTEPAD_RESET_POSITIONS"] = {
        enUS = "Reset positions",
        deDE = "Positionen zurücksetzen",
    },
    ["NOTEPAD_COMMAND_HELP"] = {
        enUS = "Show notepad commands",
        deDE = "Notizblock-Befehle anzeigen",
    },
    ["NOTEPAD_HELP_TOGGLE"] = {
        enUS = "/ytools notepad toggle - Open or close your notes.",
        deDE = "/ytools notepad toggle - Notizen öffnen oder schließen.",
    },
    ["NOTEPAD_HELP_SHOW"] = {
        enUS = "/ytools notepad show - Open your notes.",
        deDE = "/ytools notepad show - Notizen öffnen.",
    },
    ["NOTEPAD_HELP_HIDE"] = {
        enUS = "/ytools notepad hide - Close your notes.",
        deDE = "/ytools notepad hide - Notizen schließen.",
    },
    ["NOTEPAD_HELP_RESET"] = {
        enUS = "/ytools notepad reset - Reset button and window positions; keep notes.",
        deDE = "/ytools notepad reset - Positionen der Schaltfläche und des Fensters zurücksetzen; Notizen bleiben erhalten.",
    },
    ["NOTEPAD_RESET_DONE"] = {
        enUS = "Notepad positions reset. Your notes have been kept.",
        deDE = "Notiz-Positionen zurückgesetzt.",
    },
    ["UTILITY_NOTEPAD"] = {
        enUS = "Utility > Notepad     /ytools notepad",
        deDE = "Werkzeuge > Notizen     /ytools notepad",
    },
    ["NOTEPAD"] = {
        enUS = "Notepad",
        deDE = "Notizen",
    },
    ["NOTEPAD_DESCRIPTION"] = {
        enUS = "Adds a movable notepad button. Separate tabs for Account and Character. Changes are saved automatically.",
        deDE = "Zeigt eine verschiebbare Notizen-Schaltfläche. Separate Tabs für Account und Charakter. Änderungen werden automatisch gespeichert.",
    },
    ["ENABLE_NOTEPAD"] = { enUS = "Enable notepad", deDE = "Notizen aktivieren" },
    ["NOTEPAD_SHOW_MINIMAP_BUTTON"] = { enUS = "Show minimap button", deDE = "Minikarten-Schaltfläche anzeigen" },
    ["NOTEPAD_ACCOUNT"] = {
        enUS = "Account",
        deDE = "Account",
    },
    ["NOTEPAD_BUTTON_TOOLTIP"] = {
        enUS = "Click to open or close your notes. Hold Ctrl and drag to move around the minimap. Hold Ctrl+Alt+Shift and drag to move freely. Right-click for reset options.",
        deDE = "Klicken, um die Notizen zu öffnen oder zu schließen. Mit Strg um die Minikarte ziehen. Zum freien Verschieben Strg+Alt+Umschalt gedrückt halten und ziehen. Rechtsklick für die Zurücksetzoption.",
    },
    ["FISHING_OPTIONS"] = {
        enUS = "Fishing helper",
        deDE = "Angelhilfe",
    },
    ["ENABLE_FISHING"] = {
        enUS = "Enable fishing helper",
        deDE = "Angelhilfe aktivieren",
    },
    ["ENHANCE_FISHING_SOUNDS"] = {
        enUS = "Enhance sounds while fishing",
        deDE = "Geräusche beim Angeln hervorheben",
    },
    ["DOUBLE_FISHING_VOLUME"] = {
        enUS = "Double total volume while fishing (max. 100%)",
        deDE = "Gesamtlautstärke beim Angeln verdoppeln (max. 100 %)",
    },
    ["FISHING_SOUNDS_DESCRIPTION"] = {
        enUS = "While channeling Fishing, set sound effects to 100% and reduce music, ambience and dialogue to 10% of their usual volume. Restore your settings when fishing ends. Sound also plays while WoW is in the background. Optionally double master volume, capped at 100%. Other sound effects also become louder.",
        deDE = "Während des Angelns werden die Soundeffekte auf 100 % erhöht. Musik, Umgebungsgeräusche und Dialoge werden auf 10 % ihrer bisherigen Lautstärke reduziert. Nach dem Angeln werden die Einstellungen wiederhergestellt. Der Sound bleibt auch aktiv, wenn WoW im Hintergrund läuft. Optional wird die Gesamtlautstärke verdoppelt, höchstens auf 100 %. Andere Soundeffekte werden ebenfalls lauter.",
    },
    ["UNKNOWN"] = {
        enUS = "Unknown",
        deDE = "Unbekannt",
    },
    ["CFFFF0000YTOOLS_ERROR_R"] = {
        enUS = "Error: ",
        deDE = "Fehler: ",
    },
    ["FAILED_DURING"] = {
        enUS = " failed during ",
        deDE = " fehlgeschlagen bei ",
    },
    ["REGISTEREVENT_REQUIRES_AN_EVENT_NAME"] = {
        enUS = "RegisterEvent requires an event name.",
        deDE = "RegisterEvent benötigt einen Ereignisnamen.",
    },
    ["REGISTEREVENT_REQUIRES_A_CALLBACK"] = {
        enUS = "RegisterEvent requires a callback.",
        deDE = "RegisterEvent benötigt eine Callback-Funktion.",
    },
    ["REGISTERSLASHCOMMAND_REQUIRES_A_COMMAND"] = {
        enUS = "RegisterSlashCommand requires a command.",
        deDE = "RegisterSlashCommand benötigt einen Befehl.",
    },
    ["REGISTERSLASHCOMMAND_REQUIRES_A_CALLBACK"] = {
        enUS = "RegisterSlashCommand requires a callback.",
        deDE = "RegisterSlashCommand benötigt eine Callback-Funktion.",
    },
    ["SLASH_COMMAND_ALREADY_REGISTERED"] = {
        enUS = "Slash command already registered: ",
        deDE = "Befehl bereits registriert: ",
    },
    ["YTOOLS_REGISTERMODULE_REQUIRES_A_MODULE_ID"] = {
        enUS = "yTools:RegisterModule requires a module ID.",
        deDE = "yTools:RegisterModule benötigt eine Modul-ID.",
    },
    ["YTOOLS_MODULE_ALREADY_REGISTERED"] = {
        enUS = "yTools module already registered: ",
        deDE = "yTools-Modul bereits registriert: ",
    },
    ["EVENT"] = {
        enUS = "event ",
        deDE = "Ereignis ",
    },
    ["CFF00FF00_YTOOLS_OPTIONS_R_OPEN_YTOOLS_OPTIONS"] = {
        enUS = "|cff00ff00/ytools options|r - Open yTools options",
        deDE = "|cff00ff00/ytools options|r - yTools-Optionen öffnen",
    },
    ["MODULE_COMMAND"] = {
        enUS = "Module command",
        deDE = "Modulbefehl",
    },
    ["IS_DISABLED"] = {
        enUS = " is disabled.",
        deDE = " ist deaktiviert.",
    },
    ["SLASH_COMMAND"] = {
        enUS = "slash command ",
        deDE = "Befehl ",
    },
    ["ENABLE_OR_DISABLE_INDIVIDUAL_YTOOLS_MODULES_YTOOLS_HELP"] = {
        enUS = "Enable or disable individual yTools modules.     /ytools help",
        deDE = "Aktiviere oder deaktiviere einzelne yTools-Module.     /ytools help",
    },
    ["MODULES"] = {
        enUS = "Modules",
        deDE = "Module",
    },
    ["SETTINGS_API_IS_UNAVAILABLE"] = {
        enUS = "Settings API is unavailable.",
        deDE = "Die Einstellungs-API ist nicht verfügbar.",
    },
    ["UI_FRAMERATE"] = {
        enUS = "UI > Framerate     /ytools framerate",
        deDE = "UI > Framerate     /ytools framerate",
    },
    ["REPOSITION_FRAMERATE_TO_TOP_LEFT"] = {
        enUS = "Makes the framerate indicator movable and remembers its position.",
        deDE = "Macht die Framerate-Anzeige verschiebbar und speichert ihre Position.",
    },
    ["AURAS_HIDE_BUFF_LIST_BUTTON"] = {
        enUS = "Auras > Hide Buff List Button",
        deDE = "Auren > Bufflisten-Button ausblenden",
    },
    ["HIDES_THE_BUFF_LIST_COLLAPSE_AND_EXPAND_BUTTON"] = {
        enUS = "Hides the buff list collapse and expand button.",
        deDE = "Blendet den Button zum Ein- und Ausklappen der Buffliste aus.",
    },
    ["ACTIONBARS_CAST_ON_KEY_RELEASE"] = {
        enUS = "ActionBars > Cast on Key Release",
        deDE = "Aktionsleisten > Zaubern beim Loslassen",
    },
    ["ENABLED_CAST_ON_KEY_RELEASE_DISABLED_CAST_ON_KEY_PRESS"] = {
        enUS = "Enabled: cast on key release. Disabled: cast on key press.",
        deDE = "Aktiviert: Zaubern beim Loslassen der Taste. Deaktiviert: Zaubern beim Drücken.",
    },
    ["TOOLTIP_UNIT_IDS"] = {
        enUS = "Tooltip > Unit IDs",
        deDE = "Tooltip > Einheiten-IDs",
    },
    ["SHOWS_NPC_ENTRY_IDS_IN_CREATURE_PET_VEHICLE_AND_CORPSE_TOOLTIPS"] = {
        enUS = "Shows NPC entry IDs in creature, pet, vehicle and corpse tooltips.",
        deDE = "Zeigt NPC-IDs in Tooltips von Kreaturen, Begleitern, Fahrzeugen und Leichen.",
    },
    ["NPC_ID"] = {
        enUS = "NPC ID:",
        deDE = "NPC-ID:",
    },
    ["TOOLTIP_TARGETTARGET"] = {
        enUS = "Tooltip > TargetTarget",
        deDE = "Tooltip > Ziel des Ziels",
    },
    ["SHOWS_THE_HOVERED_UNIT_S_CURRENT_TARGET_IN_ITS_TOOLTIP"] = {
        enUS = "Shows the hovered unit's current target in its tooltip.",
        deDE = "Zeigt das aktuelle Ziel der Einheit unter dem Mauszeiger im Tooltip.",
    },
    ["TARGET"] = {
        enUS = "Target:",
        deDE = "Ziel:",
    },
    ["NO_TARGET"] = {
        enUS = "No target",
        deDE = "Kein Ziel",
    },
    ["UTILITIES_MACRO_MANAGER_YTOOLS_MACRO"] = {
        enUS = "Utilities > Macro Manager     /ytools macro",
        deDE = "Werkzeuge > Macro Manager     /ytools macro",
    },
    ["MACRO_DESCRIPTION"] = {
        enUS = "Creates harm, help, hybrid, and general targeting macros from the options form or slash command.",
        deDE = "Erstellt Schadens-, Heil-, Hybrid- und allgemeine Zielmakros über die Optionen oder den Chatbefehl.",
    },
    ["CFF00CCFF_YTOOLS_MACRO_MANAGER_R"] = {
        enUS = "|cff00ccff===== yTools - Macro Manager =====|r",
        deDE = "|cff00ccff===== yTools - Macro Manager =====|r",
    },
    ["CFFFFFF00CHARACTER_MACROS_R"] = {
        enUS = "|cffffff00Character macros:|r",
        deDE = "|cffffff00Charaktermakros:|r",
    },
    ["CFFFFFF00GENERAL_MACROS_R"] = {
        enUS = "|cffffff00General macros:|r",
        deDE = "|cffffff00Accountmakros:|r",
    },
    ["MACRO_MANAGER"] = {
        enUS = "Macro Manager",
        deDE = "Macro Manager",
    },
    ["MACRO_MANAGER_2"] = {
        enUS = "Macro Manager - ",
        deDE = "Macro Manager - ",
    },
    ["THE_GENERATED_MACRO_IS"] = {
        enUS = "The generated macro is ",
        deDE = "Das erstellte Makro ist ",
    },
    ["CHARACTERS_LONG_AND_EXCEEDS_THE"] = {
        enUS = " characters long and exceeds the ",
        deDE = " Zeichen lang und überschreitet das Limit von ",
    },
    ["CHARACTER_LIMIT"] = {
        enUS = "-character limit. ",
        deDE = " Zeichen. ",
    },
    ["THE_MACRO_IS_AVAILABLE_IN_THE_COPY_WINDOW"] = {
        enUS = "The macro is available in the copy window.",
        deDE = "Das Makro steht im Kopierfenster zur Verfügung.",
    },
    ["THE_MACRO_COULD_NOT_BE_CREATED_AUTOMATICALLY"] = {
        enUS = "The macro could not be created automatically. ",
        deDE = "Das Makro konnte nicht automatisch erstellt werden. ",
    },
    ["THE_GENERATED_MACRO_IS_AVAILABLE_IN_THE_COPY_WINDOW"] = {
        enUS = "The generated macro is available in the copy window.",
        deDE = "Das erstellte Makro steht im Kopierfenster zur Verfügung.",
    },
    ["UNKNOWN_MACRO_TYPE"] = {
        enUS = "Unknown macro type: ",
        deDE = "Unbekannter Makrotyp: ",
    },
    ["CFFFFFF00VALID_TYPES_R"] = {
        enUS = "|cffffff00Valid types:|r ",
        deDE = "|cffffff00Gültige Typen:|r ",
    },
    ["INVALID_SYNTAX"] = {
        enUS = "Invalid syntax.",
        deDE = "Ungültige Syntax.",
    },
    ["CFFFFFF00ALL_ARGUMENTS_MUST_BE_QUOTED_R"] = {
        enUS = "|cffffff00All arguments must be quoted.|r",
        deDE = "|cffffff00Alle Argumente müssen in Anführungszeichen stehen.|r",
    },
    ["HYBRID_MACROS_REQUIRE_A_NAME_HARM_SPELL_AND_HELP_SPELL"] = {
        enUS = "Hybrid macros require a name, harm spell, and help spell.",
        deDE = "Hybridmakros benötigen einen Namen, einen Schadenszauber und einen Heilzauber.",
    },
    ["MACROS_REQUIRE_A_NAME_AND_EXACTLY_ONE_SPELL"] = {
        enUS = " macros require a name and exactly one spell.",
        deDE = "-Makros benötigen einen Namen und genau einen Zauber.",
    },
    ["ENABLE_MACRO_MANAGER"] = {
        enUS = "Enable Macro Manager",
        deDE = "Macro Manager aktivieren",
    },
    ["MACRO_INSTRUCTIONS"] = {
        enUS = "Choose a type, enter spell names, then create your macro.\nSet WoW's Self Cast Key and Focus Cast Key to None to avoid conflicts.",
        deDE = "Wähle einen Typ, gib die Zaubernamen ein und erstelle dein Makro.\nSetze WoWs Tasten für Selbstzauber und Fokuszauber auf Keine, um Konflikte zu vermeiden.",
    },
    ["FOCUS_MODIFIER"] = {
        enUS = "Focus modifier",
        deDE = "Fokus-Modifikator",
    },
    ["PLAYER_MODIFIER"] = {
        enUS = "Player modifier",
        deDE = "Spieler-Modifikator",
    },
    ["MACRO_NAME"] = {
        enUS = "Macro name",
        deDE = "Makroname",
    },
    ["HARM_SPELL"] = {
        enUS = "Harm spell",
        deDE = "Schadenszauber",
    },
    ["HELP_SPELL"] = {
        enUS = "Help spell",
        deDE = "Heilzauber",
    },
    ["MACRO_TEXT_UPDATES_LIVE_SELECT_AND_PRESS_CTRL_C_TO_COPY"] = {
        enUS = "Macro text (updates live; select and press Ctrl+C to copy)",
        deDE = "Makrotext (aktualisiert sich sofort; markieren und mit Strg+C kopieren)",
    },
    ["CHOOSE_A_PRESET"] = {
        enUS = "Choose a preset.",
        deDE = "Wähle eine Vorlage.",
    },
    ["ENTER_A_MACRO_NAME"] = {
        enUS = "Enter a macro name.",
        deDE = "Gib einen Makronamen ein.",
    },
    ["MACRO_NAMES_MUST_BE_AT_MOST_16_BYTES"] = {
        enUS = "Macro names must be at most 16 bytes.",
        deDE = "Makronamen dürfen höchstens 16 Bytes lang sein.",
    },
    ["ENTER_A_SPELL_NAME"] = {
        enUS = "Enter a spell name.",
        deDE = "Gib einen Zaubernamen ein.",
    },
    ["ENTER_BOTH_THE_HARM_AND_HELP_SPELL_NAMES"] = {
        enUS = "Enter both the harm and help spell names.",
        deDE = "Gib den Namen des Schadenszaubers und des Heilzaubers ein.",
    },
    ["SPELL_NAMES_MUST_BE_ON_ONE_LINE"] = {
        enUS = "Spell names must be on one line.",
        deDE = "Zaubernamen müssen in einer Zeile stehen.",
    },
    ["CREATE_MACRO"] = {
        enUS = "Create macro",
        deDE = "Makro erstellen",
    },
    ["MACRO_CREATED"] = {
        enUS = "Macro created",
        deDE = "Makro erstellt",
    },
    ["MACRO_NOT_CREATED"] = {
        enUS = "Macro not created",
        deDE = "Makro nicht erstellt",
    },
    ["ENABLE_MACRO_MANAGER_IN_THE_YTOOLS_MODULE_LIST_TO_CREATE_MACROS"] = {
        enUS = "Enable Macro Manager in the yTools module list to create macros.",
        deDE = "Aktiviere den Macro Manager in der yTools-Modulliste, um Makros zu erstellen.",
    },
    ["TEXT_255_CHARACTERS"] = {
        enUS = "/255 characters",
        deDE = "/255 Zeichen",
    },
    ["TOO_LONG_CREATION_OPENS_THE_COPY_WINDOW"] = {
        enUS = " - Too long; creation opens the copy window.",
        deDE = " - Zu lang; beim Erstellen öffnet sich das Kopierfenster.",
    },
    ["CTRL_OR_SHIFT_DEFAULT"] = {
        enUS = "Ctrl or Shift (default)",
        deDE = "Strg oder Umschalt (Standard)",
    },
    ["THE_MACRO_TEXT_IS_EMPTY"] = {
        enUS = "The macro text is empty.",
        deDE = "Der Makrotext ist leer.",
    },
    ["GENERATE_AND_CREATE_A_WOW_MACRO"] = {
        enUS = "Generate and create a WoW macro.",
        deDE = "Ein WoW-Makro generieren und erstellen.",
    },
    ["TYPE"] = {
        enUS = "Type",
        deDE = "Typ",
    },
    ["STORAGE"] = {
        enUS = "Storage",
        deDE = "Speicher",
    },
    ["PRESET"] = {
        enUS = "Preset",
        deDE = "Vorlage",
    },
    ["SPELL"] = {
        enUS = "Spell",
        deDE = "Zauber",
    },
    ["GENERAL"] = {
        enUS = "General",
        deDE = "Allgemein",
    },
    ["HARM"] = {
        enUS = "Harm",
        deDE = "Schaden",
    },
    ["HELP"] = {
        enUS = "Help",
        deDE = "Heilung",
    },
    ["HYBRID"] = {
        enUS = "Hybrid",
        deDE = "Hybrid",
    },
    ["CHARACTER"] = {
        enUS = "Character",
        deDE = "Charakter",
    },
    ["ACCOUNT"] = {
        enUS = "Account",
        deDE = "Account",
    },
    ["ALT"] = {
        enUS = "Alt",
        deDE = "Alt",
    },
    ["CTRL"] = {
        enUS = "Ctrl",
        deDE = "Strg",
    },
    ["SHIFT"] = {
        enUS = "Shift",
        deDE = "Umschalt",
    },
    ["CHANNELING"] = {
        enUS = "Channeling",
        deDE = "Channeling",
    },
    ["AUTO_FOCUS_CC"] = {
        enUS = "Auto-focus CC",
        deDE = "CC mit Auto-Fokus",
    },
    ["COMPREHEND_SCROLL"] = {
        enUS = "Comprehend Scroll",
        deDE = "Schriftrolle verstehen",
    },
    ["DISENCHANT"] = {
        enUS = "Disenchant",
        deDE = "Entzaubern",
    },
    ["BAGS_MOVABLE_BAGS_YTOOLS_BAGRESET"] = {
        enUS = "Bags > Movable Bags     /ytools bagreset",
        deDE = "Taschen > Verschiebbare Tasche     /ytools bagreset",
    },
    ["MAKES_THE_COMBINED_BAG_MOVABLE_AND_SAVES_ITS_POSITION"] = {
        enUS = "Makes the combined bag movable and saves its position.",
        deDE = "Macht die kombinierte Tasche verschiebbar und speichert ihre Position.",
    },
    ["BAG_FRAME_NOT_FOUND"] = {
        enUS = "bag frame not found.",
        deDE = "Taschenfenster nicht gefunden.",
    },
    ["BAG_POSITION_RESET"] = {
        enUS = "bag position reset.",
        deDE = "Taschenposition zurückgesetzt.",
    },
    ["RESET_THE_COMBINED_BAG_POSITION"] = {
        enUS = "Reset the combined bag position.",
        deDE = "Position der kombinierten Tasche zurücksetzen.",
    },
    ["UI_HIDE_LUA_ERRORS"] = {
        enUS = "UI > Hide Lua Errors",
        deDE = "UI > Lua-Fehler ausblenden",
    },
    ["ACTIVATE_TO_HIDE_LUA_ERRORS"] = {
        enUS = "Activate to hide Lua errors.",
        deDE = "Aktivieren, um Lua-Fehler auszublenden.",
    },
    ["ACTIONBARS_HIDE_MACRO_TEXT"] = {
        enUS = "ActionBars > Hide Macro Text",
        deDE = "Aktionsleisten > Makrotext ausblenden",
    },
    ["HIDES_THE_MACRO_NAME_TEXT_DISPLAYED_ON_ACTION_BAR_BUTTONS"] = {
        enUS = "Hides the macro/name text displayed on action bar buttons.",
        deDE = "Blendet Makro- und Namenstext auf Aktionsleisten-Buttons aus.",
    },
    ["UNITFRAMES_HIDE_HIT_INDICATOR"] = {
        enUS = "Unitframes > Hide Hit Indicator",
        deDE = "Einheitenfenster > Trefferanzeige ausblenden",
    },
    ["HIDES_THE_HIT_INDICATOR_ON_PLAYERFRAME"] = {
        enUS = "Hides hit indicators on the player and pet frames.",
        deDE = "Blendet die Trefferanzeigen im Spieler- und Begleiterfenster aus.",
    },
    ["ACTIONBARS_HIDE_PAGE_INDICATOR"] = {
        enUS = "ActionBars > Hide Page Indicator",
        deDE = "Aktionsleisten > Seitenanzeige ausblenden",
    },
    ["HIDES_THE_ACTION_BAR_PAGE_INDICATOR"] = {
        enUS = "Hides the action bar page indicator.",
        deDE = "Blendet die Seitenanzeige der Aktionsleiste aus.",
    },
    ["CHAT_ARROW_KEYS"] = {
        enUS = "Chat > Arrow Keys",
        deDE = "Chat > Pfeiltasten",
    },
    ["ALLOWS_ARROW_KEYS_IN_CHAT_EDIT_BOXES_WITHOUT_HOLDING_ALT"] = {
        enUS = "Allows arrow keys in chat edit boxes without holding Alt.",
        deDE = "Erlaubt Pfeiltasten im Chateingabefeld, ohne Alt gedrückt zu halten.",
    },
    ["TOOLTIP_ITEM_IDS"] = {
        enUS = "Tooltip > Item IDs",
        deDE = "Tooltip > Gegenstand-IDs",
    },
    ["SHOWS_ITEM_IDS_IN_BAG_EQUIPMENT_LOOT_LINKED_ITEM_AND_COMPARISON_TOOLTIPS"] = {
        enUS = "Shows item IDs in bag, equipment, loot, linked-item and comparison tooltips.",
        deDE = "Zeigt Gegenstand-IDs in Taschen-, Ausrüstungs-, Beute-, Link- und Vergleichstooltips.",
    },
    ["ITEM_ID"] = {
        enUS = "Item ID:",
        deDE = "Gegenstand-ID:",
    },
    ["UI_HIDE_PTR_ISSUE_REPORTER"] = {
        enUS = "UI > Hide PTR Issue Reporter",
        deDE = "UI > PTR-Fehlermelder ausblenden",
    },
    ["HIDES_THE_PTR_ISSUE_REPORTER_FRAME"] = {
        enUS = "Hides the PTR Issue Reporter frame.",
        deDE = "Blendet das Fenster des PTR-Fehlermelders aus.",
    },
    ["TARGET_THREAT_MODULE"] = {
        enUS = "Unitframes > Target Threat",
        deDE = "Einheitenfenster > Zielbedrohung",
    },
    ["TARGET_THREAT_TITLE"] = { enUS = "Target Threat", deDE = "Zielbedrohung" },
    ["TARGET_THREAT_SHOW_PET"] = { enUS = "Show pet threat", deDE = "Bedrohung des Begleiters anzeigen" },
    ["TARGET_THREAT_DESCRIPTION"] = {
        enUS = "Shows your threat on the opposite side of the target frame from its buffs and debuffs. When first, compares your threat with the next-highest known unit.",
        deDE = "Zeigt deine Bedrohung auf der gegenüberliegenden Seite der Stärkungs- und Schwächungszauber am Zielfenster. Auf Platz eins wird sie mit der nächsthöchsten bekannten Einheit verglichen.",
    },
    ["UNITFRAMES_PLAYER_BORDER_YTOOLS_PLAYERBORDER"] = {
        enUS = "Unitframes > Player Border     /ytools playerborder",
        deDE = "Einheitenfenster > Spielerrahmen     /ytools playerborder",
    },
    ["ADDS_A_SELECTABLE_BORDER_TO_THE_PLAYER_FRAME"] = {
        enUS = "Adds a selectable border to the player frame.",
        deDE = "Fügt dem Spielerfenster einen wählbaren Rahmen hinzu.",
    },
    ["DEFAULT_DISABLED"] = {
        enUS = "Default / Disabled",
        deDE = "Standard / Deaktiviert",
    },
    ["SILVER_WINGS"] = {
        enUS = "Silver + Wings",
        deDE = "Silber + Flügel",
    },
    ["GOLD_WINGS"] = {
        enUS = "Gold + Wings",
        deDE = "Gold + Flügel",
    },
    ["SILVER"] = {
        enUS = "Silver",
        deDE = "Silber",
    },
    ["GOLD"] = {
        enUS = "Gold",
        deDE = "Gold",
    },
    ["CFF00CCFF_YTOOLS_PORTRAIT_BORDER_R"] = {
        enUS = "|cff00ccff===== yTools - Portrait Border =====|r",
        deDE = "|cff00ccff===== yTools - Porträtrahmen =====|r",
    },
    ["CFF00FF00CURRENT_R"] = {
        enUS = "|cff00ff00Current:|r ",
        deDE = "|cff00ff00Aktuell:|r ",
    },
    ["UNKNOWN_PORTRAIT_BORDER"] = {
        enUS = "Unknown portrait border: ",
        deDE = "Unbekannter Porträtrahmen: ",
    },
    ["PORTRAIT_BORDER_CHANGED_TO"] = {
        enUS = "Portrait border changed to ",
        deDE = "Porträtrahmen geändert zu ",
    },
    ["PLAYER_BORDER"] = {
        enUS = "Player Border",
        deDE = "Spielerrahmen",
    },
    ["ENABLE_PLAYER_BORDER"] = {
        enUS = "Enable Player Border",
        deDE = "Spielerrahmen aktivieren",
    },
    ["CHOOSE_THE_BORDER_AROUND_YOUR_PLAYER_PORTRAIT_CHANGES_APPLY_IMMEDIATELY"] = {
        enUS = "Choose the border around your player portrait. Changes apply immediately.",
        deDE = "Wähle den Rahmen um dein Spielerporträt. Änderungen werden sofort übernommen.",
    },
    ["BORDER_STYLE"] = {
        enUS = "Border style",
        deDE = "Rahmenstil",
    },
    ["SHOW_OR_CHANGE_PLAYERFRAME_BORDER"] = {
        enUS = "Show or change playerframe border.",
        deDE = "Spielerrahmen anzeigen oder ändern.",
    },
    ["TOOLTIP_VENDOR_PRICE"] = {
        enUS = "Tooltip > Vendor Price",
        deDE = "Tooltip > Verkaufspreis",
    },
    ["SHOWS_THE_VENDOR_PRICE_PER_ITEM_HOLD_SHIFT_TO_SHOW_THE_PRICE_OF_THE_WHOLE_STACK"] = {
        enUS = "Shows the vendor price per item. Hold Shift to show the price of the whole stack.",
        deDE = "Zeigt den Verkaufspreis pro Gegenstand. Halte Umschalt gedrückt, um den Preis des gesamten Stapels anzuzeigen.",
    },
    ["CHAT_COPY_CHAT_YTOOLS_COPYCHAT"] = {
        enUS = "Chat > Copy Chat     /ytools copychat",
        deDE = "Chat > Chat kopieren     /ytools copychat",
    },
    ["ADDS_A_BUTTON_TO_CHAT_WINDOWS_THAT_OPENS_THEIR_CONTENTS_IN_A_COPYABLE_WINDOW"] = {
        enUS = "Adds a button to chat windows that opens their contents in a copyable window.",
        deDE = "Fügt Chatfenstern einen Button hinzu, der ihren Inhalt in einem Kopierfenster öffnet.",
    },
    ["CHAT_COPY"] = {
        enUS = "Chat Copy",
        deDE = "Chat kopieren",
    },
    ["COMBAT_LOG_COPYING_IS_NOT_SUPPORTED"] = {
        enUS = "Combat Log copying is not supported.",
        deDE = "Das Kopieren des Kampflogs wird nicht unterstützt.",
    },
    ["CHAT_COPY_2"] = {
        enUS = "Chat Copy - ",
        deDE = "Chat kopieren - ",
    },
    ["COPY_CHAT"] = {
        enUS = "Copy Chat",
        deDE = "Chat kopieren",
    },
    ["COPY_ALL_CHAT_MESSAGES_FROM_THIS_WINDOW"] = {
        enUS = "Copy all chat messages from this window.",
        deDE = "Alle Chatnachrichten aus diesem Fenster kopieren.",
    },
    ["COPY_THE_CONTENTS_OF_THE_SELECTED_CHAT_WINDOW"] = {
        enUS = "Copy the contents of the selected chat window.",
        deDE = "Inhalt des ausgewählten Chatfensters kopieren.",
    },
    ["AUTO_QUEST_TITLE"] = {
        enUS = "Auto Quest Turn-In/Accept",
        deDE = "Quests automatisch abgeben/annehmen",
    },
    ["AUTO_QUEST_MODIFIER"] = {
        enUS = "Modifier key",
        deDE = "Modifikatortaste",
    },
    ["AUTO_QUEST_REQUIRE_MODIFIER"] = {
        enUS = "Only automate while holding the modifier",
        deDE = "Nur bei gedrückter Modifikatortaste automatisieren",
    },
    ["AUTO_QUEST_CHOOSE_REWARD"] = {
        enUS = "Choose a reward",
        deDE = "Wähle eine Belohnung",
    },
    ["AUTO_QUEST_MODULE"] = {
        enUS = "Automation > Auto Quest Turn-In/Accept",
        deDE = "Automation > Quests automatisch abgeben/annehmen",
    },
    ["AUTO_QUEST_DESCRIPTION"] = {
        enUS = "Automatically accepts quests and turns in completed quests. By default, holding the modifier pauses automation. You can reverse this in the settings. Quests with a fee or a choice of rewards are left to you.",
        deDE = "Nimmt Quests automatisch an und gibt abgeschlossene Quests ab. Standardmäßig pausiert die Modifikatortaste die Automatisierung. In den Einstellungen kannst du das Verhalten umkehren. Quests mit einer Gebühr oder Belohnungsauswahl gibst du selbst ab.",
    },
    ["AUTOMATION_AUTO_REPAIR"] = {
        enUS = "Automation > Auto Repair",
        deDE = "Automation > Automatisch reparieren",
    },
    ["AUTOMATICALLY_REPAIRS_EQUIPMENT_WHEN_VISITING_A_MERCHANT"] = {
        enUS = "Automatically repairs equipment when visiting a merchant.",
        deDE = "Repariert Ausrüstung automatisch beim Besuch eines Händlers.",
    },
    ["UNITFRAMES_CAST_BAR_POSITIONS"] = {
        enUS = "Unitframes > Cast Bar Positions     /ytools castbars",
        deDE = "Einheitenfenster > Zauberleistenpositionen     /ytools castbars",
    },
    ["LOCKS_THE_TARGET_AND_FOCUS_CAST_BARS_TO_CUSTOM_POSITIONS"] = {
        enUS = "Locks the Target, and Focus cast bars to custom positions.",
        deDE = "Fixiert die Zauberleisten von Ziel und Fokus an eigenen Positionen.",
    },
    ["AUTOMATION_FISHING"] = {
        enUS = "Automation > Fishing helper     /ytools fishing",
        deDE = "Automation > Angelhilfe     /ytools fishing",
    },
    ["DOUBLE_RIGHT_CLICK_IN_THE_WORLD_WITH_A_FISHING_ROD_EQUIPPED_TO_CAST_FISHING_DOES_NOT"] = {
        enUS = "Double right-click in the world with a fishing rod equipped to cast Fishing.",
        deDE = "Doppelter Rechtsklick in der Spielwelt wirft die Angel aus, wenn eine Angel ausgerüstet ist.",
    },
    ["TOOLTIP_SPELL_IDS"] = {
        enUS = "Tooltip > Spell IDs",
        deDE = "Tooltip > Zauber-IDs",
    },
    ["SHOWS_SPELL_IDS_IN_SPELL_ACTION_BAR_BUFF_AND_DEBUFF_TOOLTIPS"] = {
        enUS = "Shows spell IDs in spell, action-bar, buff and debuff tooltips.",
        deDE = "Zeigt Zauber-IDs in Zauber-, Aktionsleisten-, Buff- und Debuff-Tooltips.",
    },
    ["SPELL_ID"] = {
        enUS = "Spell ID:",
        deDE = "Zauber-ID:",
    },
    ["AUTOMATION_AUTO_SELL_JUNK"] = {
        enUS = "Automation > Auto Sell Junk",
        deDE = "Automation > Plunder automatisch verkaufen",
    },
    ["AUTOMATICALLY_SELLS_JUNK_ITEMS_WHEN_VISITING_A_MERCHANT"] = {
        enUS = "Automatically sells junk items when visiting a merchant.",
        deDE = "Verkauft Plunder automatisch beim Besuch eines Händlers.",
    },
    ["BAG_SLOTS_MODULE"] = {
        enUS = "Bags > Bag Slots     /ytools bagslots",
        deDE = "Taschen > Taschenplätze     /ytools bagslots",
    },
    ["BAG_SLOTS_DESCRIPTION"] = {
        enUS = "Arranges slots in the combined bag from top-left to bottom-right. Optionally reverses the displayed slot order.",
        deDE = "Ordnet Plätze im kombinierten Taschenfenster von oben links nach unten rechts an. Die angezeigte Reihenfolge kann umgekehrt werden.",
    },
    ["UI_ROLLFRAME_YTOOLS_ROLLFRAME"] = {
        enUS = "UI > Rollframe     /ytools rollframe",
        deDE = "UI > Würfelfenster     /ytools rollframe",
    },
    ["MOVE_THE_DEFAULT_ROLLFRAME"] = {
        enUS = "Move the default Rollframe.",
        deDE = "Verschiebt das Standard-Würfelfenster.",
    },
    ["ROLLFRAME_POSITION"] = {
        enUS = "Rollframe Position",
        deDE = "Position des Würfelfensters",
    },
    ["DRAG_TO_MOVE_YTOOLS_ROLLFRAME_LOCK"] = {
        enUS = "Drag to move - /ytools rollframe lock",
        deDE = "Zum Verschieben ziehen - /ytools rollframe lock",
    },
    ["ADDITIONAL_ROLLS_GROW_DOWN"] = {
        enUS = "Additional rolls grow down",
        deDE = "Weitere Würfelwürfe nach unten anordnen",
    },
    ["ROLLFRAME_POSITION_LOCKED"] = {
        enUS = "Rollframe position locked.",
        deDE = "Position des Würfelfensters gesperrt.",
    },
    ["ROLLFRAME_POSITION_UNLOCKED"] = {
        enUS = "Rollframe position unlocked. ",
        deDE = "Position des Würfelfensters entsperrt. ",
    },
    ["DRAG_THE_GREEN_BOX_THEN_USE"] = {
        enUS = "Drag the green box, then use ",
        deDE = "Ziehe das grüne Feld und verwende dann ",
    },
    ["YTOOLS_ROLLFRAME_LOCK"] = {
        enUS = "/ytools rollframe lock.",
        deDE = "/ytools rollframe lock.",
    },
    ["ROLLFRAME_POSITION_RESET"] = {
        enUS = "Rollframe position reset.",
        deDE = "Position des Würfelfensters zurückgesetzt.",
    },
    ["CFF00CCFF_YTOOLS_ROLLFRAME_R"] = {
        enUS = "|cff00ccff===== yTools - Rollframe =====|r",
        deDE = "|cff00ccff===== yTools - Würfelfenster =====|r",
    },
    ["TOGGLE_LOCK_STATE"] = {
        enUS = " - toggle lock state",
        deDE = " - Sperre umschalten",
    },
    ["UNLOCK_AND_SHOW_MOVER"] = {
        enUS = " - unlock and show mover",
        deDE = " - Entsperren und Verschiebehilfe anzeigen",
    },
    ["LOCK_AND_HIDE_MOVER"] = {
        enUS = " - lock and hide mover",
        deDE = " - Sperren und Verschiebehilfe ausblenden",
    },
    ["RESET_POSITION"] = {
        enUS = " - reset position",
        deDE = " - Position zurücksetzen",
    },
    ["UNKNOWN_ROLLFRAME_COMMAND"] = {
        enUS = "Unknown rollframe command: ",
        deDE = "Unbekannter Würfelfenster-Befehl: ",
    },
    ["MOVE_THE_DEFAULT_ROLLFRAME_2"] = {
        enUS = "Move the default rollframe.",
        deDE = "Standard-Würfelfenster verschieben.",
    },
    ["MACRO_USAGE_1"] = {
        enUS = "/ytools macro harm \"Name\" \"Spell Name\"",
        deDE = "/ytools macro harm \"Name\" \"Zaubername\"",
    },
    ["MACRO_USAGE_2"] = {
        enUS = "/ytools macro help \"Name\" \"Spell Name\"",
        deDE = "/ytools macro help \"Name\" \"Zaubername\"",
    },
    ["MACRO_USAGE_3"] = {
        enUS = "/ytools macro hybrid \"Name\" \"Harm Spell\" \"Help Spell\"",
        deDE = "/ytools macro hybrid \"Name\" \"Schadenszauber\" \"Heilzauber\"",
    },
    ["MACRO_USAGE_4"] = {
        enUS = "/ytools macro general-harm \"Name\" \"Spell Name\"",
        deDE = "/ytools macro general-harm \"Name\" \"Zaubername\"",
    },
    ["MACRO_USAGE_5"] = {
        enUS = "/ytools macro general-help \"Name\" \"Spell Name\"",
        deDE = "/ytools macro general-help \"Name\" \"Zaubername\"",
    },
    ["MACRO_USAGE_6"] = {
        enUS = "/ytools macro general-hybrid \"Name\" \"Harm Spell\" \"Help Spell\"",
        deDE = "/ytools macro general-hybrid \"Name\" \"Schadenszauber\" \"Heilzauber\"",
    },
    ["MACRO_USAGE_7"] = {
        enUS = "\"Name\" \"Harm Spell\" \"Help Spell\"",
        deDE = "\"Name\" \"Schadenszauber\" \"Heilzauber\"",
    },
    ["MACRO_USAGE_8"] = {
        enUS = "\"Name\" \"Spell Name\"",
        deDE = "\"Name\" \"Zaubername\"",
    },
    ["TARGET_TARGET_OPTIONS"] = {
        enUS = "Tooltip > TargetTarget",
        deDE = "Tooltip > Ziel des Ziels",
    },
    ["TARGET_TARGET_DESCRIPTION"] = {
        enUS = "Show the hovered unit's current target in its tooltip.",
        deDE = "Zeigt das aktuelle Ziel der Einheit unter dem Mauszeiger im Tooltip.",
    },
    ["ENABLE_TARGET_TARGET"] = {
        enUS = "Enable TargetTarget",
        deDE = "Ziel des Ziels anzeigen",
    },
    ["SHOW_FULL_CHARACTER_NAME"] = {
        enUS = "Show first and last name",
        deDE = "Vor- und Nachnamen anzeigen",
    },
    ["FULL_CHARACTER_NAME_DESCRIPTION"] = {
        enUS = "Enabled: display the full character name. Disabled: display only the first name.",
        deDE = "Aktiviert: Zeigt den vollständigen Charakternamen. Deaktiviert: Zeigt nur den Vornamen.",
    },
    ["FRAMERATE_RESET_DONE"] = { enUS = "Framerate position reset.", deDE = "Framerate-Position zurückgesetzt." },
    ["FRAMERATE_LOCK_HELP"] = { enUS = "/ytools framerate lock -> Lock/unlock dragging.", deDE = "/ytools framerate lock -> Verschieben sperren/entsperren." },
    ["FRAMERATE_LOCKED"] = { enUS = "Framerate position locked.", deDE = "Framerate-Position gesperrt." },
    ["FRAMERATE_UNLOCKED"] = { enUS = "Framerate position unlocked.", deDE = "Framerate-Position entsperrt." },
    ["FRAMERATE_TOGGLE_HELP"] = { enUS = "/ytools framerate toggle -> Toggle the framerate indicator.", deDE = "/ytools framerate toggle -> Framerate-Anzeige ein-/ausblenden." },
    ["FRAMERATE_RESET_HELP"] = { enUS = "/ytools framerate reset -> Reset position to the top left.", deDE = "/ytools framerate reset -> Position oben links zurücksetzen." },
    ["FRAMERATE_COMMAND_HELP"] = { enUS = "/ytools framerate -> Show framerate command help.", deDE = "/ytools framerate -> Hilfe zu den Framerate-Befehlen anzeigen." },
    ["VENDOR_PRICE_DESCRIPTION"] = { enUS = "Shows the vendor price per item or stack. A configurable modifier switches between both displays.", deDE = "Zeigt den Händlerpreis pro Gegenstand oder Stapel. Eine einstellbare Zusatztaste wechselt zwischen beiden Anzeigen." },
    ["VENDOR_PRICE_DEFAULT"] = { enUS = "Default price display", deDE = "Standard-Preisanzeige" },
    ["VENDOR_PRICE_SINGLE"] = { enUS = "Single item", deDE = "Einzelner Gegenstand" },
    ["VENDOR_PRICE_STACK"] = { enUS = "Whole stack", deDE = "Ganzer Stapel" },
    ["VENDOR_PRICE_MODIFIER"] = { enUS = "Modifier for the other price display", deDE = "Zusatztaste für die andere Preisanzeige" },
    ["CASTBARS_OPTIONS"] = { enUS = "Castbars", deDE = "Zauberleisten" },
    ["MODULE_OPTIONS_ENABLE"] = { enUS = "Enable", deDE = "Aktivieren" },
    ["CASTBARS_TARGET_Y"] = { enUS = "Target castbar: Y offset from screen center", deDE = "Ziel-Zauberleiste: Y-Abstand zur Bildschirmmitte" },
    ["CASTBARS_FOCUS_Y"] = { enUS = "Focus castbar: Y offset above target castbar", deDE = "Fokus-Zauberleiste: Y-Abstand über der Ziel-Zauberleiste" },
    ["CASTBARS_COMMAND_HELP"] = { enUS = "/ytools castbars -> Open castbar options.", deDE = "/ytools castbars -> Optionen der Zauberleisten öffnen." },
    ["FALCON_TRACKER_MODULE"] = { enUS = "UI > Falcon Tracker", deDE = "UI > Falken-Tracker" },
    ["FALCON_TRACKER_TITLE"] = { enUS = "Falcon Tracker", deDE = "Falken-Tracker" },
    ["FALCON_TRACKER_ZOOM_ICONS"] = { enUS = "Zoom icons (square, black border)", deDE = "Icons vergrößern (quadratisch, schwarzer Rahmen)" },
    ["FALCON_TRACKER_SCALE"] = { enUS = "Scale", deDE = "Skalierung" },
    ["FALCON_TRACKER_HIDE_SUMMONS"] = { enUS = "Hide Blizzard's summon row", deDE = "Blizzard-Beschwörungsleiste ausblenden" },
    ["FALCON_TRACKER_POSITION"] = { enUS = "Position relative to screen center", deDE = "Position relativ zur Bildschirmmitte" },
    ["FALCON_TRACKER_RESET_POSITION"] = { enUS = "Reset position", deDE = "Position zurücksetzen" },
    ["FALCON_TRACKER_RESET_HELP"] = { enUS = "/ytools falcontracker reset — Reset position.", deDE = "/ytools falcontracker reset — Position zurücksetzen." },
    ["FALCON_TRACKER_TOTEMS_HELP"] = { enUS = "/ytools falcontracker totems — Toggle the entire Blizzard summon row.", deDE = "/ytools falcontracker totems — Die gesamte Blizzard-Beschwörungsleiste ein- oder ausblenden." },
    ["FALCON_TRACKER_POSITION_RESET"] = { enUS = "Falcon Tracker position reset.", deDE = "Position der Falkenanzeige zurückgesetzt." },
    ["FALCON_TRACKER_TOTEMS_HIDDEN"] = { enUS = "Blizzard summon row: hidden.", deDE = "Blizzard-Beschwörungsleiste: ausgeblendet." },
    ["FALCON_TRACKER_TOTEMS_SHOWN"] = { enUS = "Blizzard summon row: visible.", deDE = "Blizzard-Beschwörungsleiste: sichtbar." },
    ["FALCON_TRACKER_DESCRIPTION"] = {
        enUS = "Shows timers for summoned falcons and highlights Arcane Shot when both are active. Hold Ctrl+Alt+Shift to show and drag.",
        deDE = "Zeigt die Restdauer beschworener Falken und hebt Arkaner Schuss hervor, wenn beide aktiv sind. Zum Anzeigen und Verschieben Strg+Alt+Umschalt gedrückt halten.",
    },
    ["HUNTERBAR_MODULE"] = { enUS = "UI > Hunter Bar     /ytools hunterbar", deDE = "UI > Jägerleiste     /ytools hunterbar" },
    ["HUNTERBAR_TITLE"] = { enUS = "Hunter Bar", deDE = "Jägerleiste" },
    ["HUNTERBAR_DESCRIPTION"] = { enUS = "Shows the ranged swing timer and highlights the Auto Shot windup. Can attach above or below the player castbar.", deDE = "Zeigt den Fernkampf-Angriffstimer und markiert die Vorbereitungszeit des automatischen Schusses. Kann oberhalb oder unterhalb der Spieler-Zauberleiste ausgerichtet werden." },
    ["HUNTERBAR_ATTACH"] = { enUS = "Position", deDE = "Position" },
    ["HUNTERBAR_FREE"] = { enUS = "Free position", deDE = "Freie Position" },
    ["HUNTERBAR_TOP"] = { enUS = "Above player castbar", deDE = "Über der Spieler-Zauberleiste" },
    ["HUNTERBAR_BOTTOM"] = { enUS = "Below player castbar", deDE = "Unter der Spieler-Zauberleiste" },
    ["HUNTERBAR_FIT_WIDTH"] = { enUS = "Match castbar width", deDE = "Breite an Zauberleiste anpassen" },
    ["HUNTERBAR_WIDTH"] = { enUS = "Width (when not matched)", deDE = "Breite (ohne Anpassung)" },
    ["HUNTERBAR_HEIGHT"] = { enUS = "Height", deDE = "Höhe" },
    ["HUNTERBAR_GAP"] = { enUS = "Gap to castbar", deDE = "Abstand zur Zauberleiste" },
    ["HUNTERBAR_WINDUP"] = { enUS = "Windup", deDE = "Vorbereitung" },
    ["HUNTERBAR_SHOW_WHEN"] = { enUS = "Show when", deDE = "Anzeigen bei" },
    ["HUNTERBAR_SHOW_COMBAT_OR_TARGET"] = { enUS = "Combat or attackable target", deDE = "Kampf oder angreifbares Ziel" },
    ["HUNTERBAR_ALWAYS_SHOW"] = { enUS = "Always", deDE = "Immer" },
    ["HUNTERBAR_ALWAYS_SHOW_COMBAT"] = { enUS = "In combat", deDE = "Im Kampf" },
    ["HUNTERBAR_ALWAYS_SHOW_TARGET"] = { enUS = "With an attackable target", deDE = "Mit angreifbarem Ziel" },
    ["HUNTERBAR_SHOT_FLASH"] = { enUS = "Flash on ranged shot", deDE = "Bei Fernkampfschuss aufblitzen" },
    ["HUNTERBAR_OPACITY"] = { enUS = "Opacity (0.1–1)", deDE = "Deckkraft (0.1–1)" },
    ["HUNTERBAR_BAR_COLOR"] = { enUS = "Bar tint", deDE = "Leistenfarbe" },
    ["HUNTERBAR_WINDUP_COLOR"] = { enUS = "Windup color", deDE = "Vorbereitungsfarbe" },
    ["HUNTERBAR_DRAG_HINT"] = { enUS = "Free position: hold Ctrl+Alt+Shift to drag. Settings and position are shared across characters. The windup defaults to 0.5 seconds, adjusted for readable ranged haste and world latency. Wait for the recovery color before moving.", deDE = "Freie Position: Zum Verschieben Strg+Alt+Umschalt gedrückt halten. Einstellungen und Position gelten für alle Charaktere. Die Vorbereitungszeit beträgt standardmäßig 0.5 Sekunden und wird an lesbares Fernkampftempo und die Weltlatenz angepasst. Warte vor dem Loslaufen auf die Erholungsfarbe." },
    ["HUNTERBAR_COMMAND_HELP"] = { enUS = "/ytools hunterbar -> Open hunter bar options.", deDE = "/ytools hunterbar -> Optionen der Jägerleiste öffnen." },
    ["HUNTERBAR_RANGE_POSITION"] = { enUS = "Range position", deDE = "Distanzposition" },
    ["HUNTERBAR_SHOW_MARKER"] = { enUS = "Show windup marker", deDE = "Vorbereitungsmarkierung anzeigen" },
    ["HUNTERBAR_OUT_OF_RANGE"] = { enUS = "Out of range", deDE = "Außer Reichweite" },
    ["HUNTERBAR_YARDS"] = { enUS = "yd", deDE = "m" },
    ["HUNTERBAR_ON_BAR"] = { enUS = "On bar", deDE = "Auf der Leiste" },
    ["HUNTERBAR_ABOVE"] = { enUS = "Above bar", deDE = "Über der Leiste" },
    ["HUNTERBAR_BELOW"] = { enUS = "Below bar", deDE = "Unter der Leiste" },
    ["HUNTERBAR_RANGE_VERTICAL"] = { enUS = "Range height", deDE = "Vertikale Distanzposition" },
    ["HUNTERBAR_TIMER_VERTICAL"] = { enUS = "Timer height", deDE = "Vertikale Timerposition" },
    ["HUNTERBAR_CENTERED"] = { enUS = "Centered", deDE = "Zentriert" },
    ["HUNTERBAR_LAYOUT"] = { enUS = "Bar layout", deDE = "Leistenlayout" },
    ["HUNTERBAR_STANDARD"] = { enUS = "Default", deDE = "Standard" },
    ["HUNTERBAR_MOVEMENT_OPACITY"] = { enUS = "Movement opacity (0–1)", deDE = "Deckkraft bei Bewegung (0–1)" },
    ["HUNTERBAR_LABEL_POSITION"] = { enUS = "Label position", deDE = "Textposition" },
    ["HUNTERBAR_TIMER_POSITION"] = { enUS = "Timer position", deDE = "Timerposition" },
    ["HUNTERBAR_LEFT"] = { enUS = "Left", deDE = "Links" },
    ["HUNTERBAR_CENTER"] = { enUS = "Center", deDE = "Mitte" },
    ["HUNTERBAR_RIGHT"] = { enUS = "Right", deDE = "Rechts" },
    ["HUNTERBAR_NONE"] = { enUS = "None", deDE = "Keine" },
}

local locale = GetLocale() == "deDE" and "deDE" or "enUS"
addon.localization = terms
addon.L = setmetatable({}, {
    __index = function(_, key)
        local term = terms[key]
        return term and (term[locale] or term.enUS) or key
    end,
})
