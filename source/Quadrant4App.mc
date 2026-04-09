import Toybox.Application;
import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Timer;
import Toybox.Attention;
import Toybox.Math;
import Toybox.Lang;
import Toybox.System;
import Toybox.Application.Storage;

// --- GLOBAL CONSTANTS ---
var ICON_X = 144;
var ICON_Y = 31;
var ICON_R = 31;

// --- MAIN APPLICATION ---
class Quadrant4App extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function getInitialView() as [Views] or [Views, InputDelegates] {
        var view = new Quadrant4View();
        return [ view, new Quadrant4Delegate(view) ];
    }
}

// --- CREDITS / ABOUT VIEW ---
class CreditsView extends WatchUi.View {
    function initialize() { View.initialize(); }
    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        var cx = dc.getWidth() / 2;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
        dc.fillCircle(ICON_X, ICON_Y, ICON_R);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(ICON_X, ICON_Y, Graphics.FONT_XTINY, "i", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        
        var sSize = 20;
        var logoX = cx - 35; 
        var logoY = 25;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawRectangle(logoX, logoY, sSize, sSize);
        dc.drawRectangle(logoX + sSize, logoY, sSize, sSize);
        dc.drawRectangle(logoX, logoY + sSize, sSize, sSize);
        dc.drawRectangle(logoX + sSize, logoY + sSize, sSize, sSize);
        
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 85, Graphics.FONT_SMALL, "Quadrant 4", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, 105, Graphics.FONT_XTINY, "v2.0.0", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setPenWidth(1);
        dc.drawLine(cx - 40, 125, cx + 40, 125);
        dc.drawText(cx, 130, Graphics.FONT_XTINY, "Made by Giuig", Graphics.TEXT_JUSTIFY_CENTER);
    }
}

// --- MAIN GAME VIEW ---
class Quadrant4View extends WatchUi.View {
    public var sequence as Array<Number> = [] as Array<Number>;
    private var playerIndex as Number = 0;
    public var isShowingSequence as Boolean = false;
    private var activeQuadrant as Number = -1; 
    private var timer as Timer.Timer;
    private var playbackIndex as Number = 0;
    public var gameState as Number = 0; 
    private var finalScore as Number = 0;

    function initialize() { View.initialize(); timer = new Timer.Timer(); }

    function startNewGame() as Void {
        gameState = 1;
        sequence = [(Math.rand() % 4)] as Array<Number>;
        showSequence();
    }

    function showSequence() as Void {
        isShowingSequence = true;
        playerIndex = 0;
        playbackIndex = 0;
        playNextInSequence();
    }

    function playNextInSequence() as Void {
        if (playbackIndex < sequence.size()) {
            activeQuadrant = sequence[playbackIndex];
            triggerFeedback(activeQuadrant, false);
            WatchUi.requestUpdate();
            timer.start(method(:turnOffQuadrant), 400, false);
        } else {
            isShowingSequence = false;
            activeQuadrant = -1;
            WatchUi.requestUpdate();
        }
    }

    function turnOffQuadrant() as Void {
        activeQuadrant = -1;
        WatchUi.requestUpdate();
        if (isShowingSequence) {
            playbackIndex++;
            var pauseTimer = new Timer.Timer();
            pauseTimer.start(method(:playNextInSequence), 200, false);
        }
    }

    function triggerFeedback(quadrant as Number, isError as Boolean) as Void {
        var soundEnabled = Storage.getValue("sound_enabled");
        var vibeEnabled = Storage.getValue("vibe_enabled");
        if (soundEnabled == null) { soundEnabled = true; }
        if (vibeEnabled == null) { vibeEnabled = true; }

        if (soundEnabled && Attention has :playTone) {
            if (isError) {
                Attention.playTone(Attention.TONE_ERROR);
            } else {
                var tones = [Attention.TONE_KEY, Attention.TONE_START, Attention.TONE_STOP, Attention.TONE_ALARM] as Array<Attention.Tone>;
                Attention.playTone(tones[quadrant]);
            }
        }

        if (vibeEnabled && Attention has :vibrate) {
            if (isError) {
                Attention.vibrate([new Attention.VibeProfile(100, 500)] as Array<Attention.VibeProfile>);
            } else {
                Attention.vibrate([new Attention.VibeProfile(50, 100)] as Array<Attention.VibeProfile>);
            }
        }
    }

    function handleInput(input as Number) as Void {
        if (gameState != 1 || isShowingSequence) { return; }
        activeQuadrant = input;
        triggerFeedback(input, false);
        WatchUi.requestUpdate();
        
        if (input == sequence[playerIndex]) {
            playerIndex++;
            var t = new Timer.Timer();
            t.start(method(:turnOffQuadrantManual), 200, false);
            if (playerIndex >= sequence.size()) {
                sequence.add(Math.rand() % 4);
                var nextRound = new Timer.Timer();
                nextRound.start(method(:showSequence), 1000, false);
            }
        } else {
            finalScore = sequence.size() - 1;
            var top = Storage.getValue("top_score");
            if (top == null || finalScore > (top as Number)) { Storage.setValue("top_score", finalScore); }
            gameState = 2;
            triggerFeedback(-1, true);
            WatchUi.requestUpdate();
        }
    }

    function turnOffQuadrantManual() as Void { activeQuadrant = -1; WatchUi.requestUpdate(); }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        var w = dc.getWidth();
        var h = dc.getHeight();
        if (gameState == 1) { drawGameScreen(dc, w, h); } 
        else if (gameState == 2) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w/2, h/2 - 25, Graphics.FONT_MEDIUM, "GAME OVER", Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(w/2, h/2 + 5, Graphics.FONT_SMALL, "Score: " + finalScore, Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(w/2, h/2 + 35, Graphics.FONT_XTINY, "Press any key", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    private function drawGameScreen(dc as Graphics.Dc, w as Number, h as Number) as Void {
        var midX = w / 2; var midY = h / 2; var dotR = 4; var pad = 12;
        if (activeQuadrant != -1) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            if (activeQuadrant == 0) { dc.fillRectangle(0, 0, midX, midY); }
            else if (activeQuadrant == 1) { dc.fillRectangle(midX, 0, midX, midY); }
            else if (activeQuadrant == 2) { dc.fillRectangle(0, midY, midX, midY); }
            else if (activeQuadrant == 3) { dc.fillRectangle(midX, midY, midX, midY); }
        }
        dc.setPenWidth(1); dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(midX, 0, midX, h); dc.drawLine(0, midY, w, midY);
        
        // Negative labels logic
        dc.setColor(activeQuadrant == 0 ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(pad, midY - pad, dotR);
        dc.setColor(activeQuadrant == 2 ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(pad, midY + (midY / 2), dotR);
        dc.setColor(activeQuadrant == 3 ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(w - pad, midY + (midY / 2), dotR);

        // Porthole Negative
        if (activeQuadrant == 1) {
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
            dc.fillCircle(ICON_X, ICON_Y, ICON_R);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
            dc.fillCircle(ICON_X, ICON_Y, ICON_R);
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        }

        if (isShowingSequence) { dc.drawText(ICON_X, ICON_Y, Graphics.FONT_XTINY, "WATCH", Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER); } 
        else { dc.drawText(ICON_X, ICON_Y, Graphics.FONT_MEDIUM, (sequence.size() - 1).toString(), Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER); }
        
        // Footer Negative
        if (activeQuadrant == 2 || activeQuadrant == 3) {
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        }
        var statusLabel = isShowingSequence ? "WATCH..." : "YOUR TURN!";
        dc.drawText(midX, h - 25, Graphics.FONT_XTINY, statusLabel, Graphics.TEXT_JUSTIFY_CENTER);
    }
}

// --- DELEGATES ---
class Quadrant4Delegate extends WatchUi.BehaviorDelegate {
    private var _view as Quadrant4View;
    function initialize(v as Quadrant4View) { BehaviorDelegate.initialize(); _view = v; var t = new Timer.Timer(); t.start(method(:pushStartMenu), 300, false); }
    function pushStartMenu() as Void {
        var menu = new WatchUi.Menu2({:title=>"Quadrant 4"});
        var top = Storage.getValue("top_score");
        menu.addItem(new WatchUi.MenuItem("Play Game", null, "start", {:icon => new PlayIcon()}));
        menu.addItem(new WatchUi.MenuItem("High Score", (top == null ? "0" : top.toString()), "top", {:icon => new TrophyIcon()}));
        menu.addItem(new WatchUi.MenuItem("Settings", null, "settings", {:icon => new GearIcon()}));
        menu.addItem(new WatchUi.MenuItem("About", "Credits & Info", "about", {:icon => new InfoIcon()}));
        WatchUi.pushView(menu, new Quadrant4MenuDelegate(_view), WatchUi.SLIDE_IMMEDIATE);
    }
    function onKey(evt as WatchUi.KeyEvent) as Boolean {
        if (_view.gameState == 2) { _view.gameState = 0; pushStartMenu(); return true; } 
        if (_view.gameState == 1) {
            var key = evt.getKey();
            if (key == WatchUi.KEY_UP) { _view.handleInput(0); return true; }
            if (key == WatchUi.KEY_ENTER) { _view.handleInput(1); return true; }
            if (key == WatchUi.KEY_DOWN) { _view.handleInput(2); return true; }
            if (key == WatchUi.KEY_ESC) { _view.handleInput(3); return true; }
        }
        return false;
    }
    function onBack() as Boolean {
        if (_view.gameState == 1) { _view.handleInput(3); return true; }
        if (_view.gameState == 2) { _view.gameState = 0; pushStartMenu(); return true; }
        return false;
    }
    function onMenu() as Boolean { if (_view.gameState != 1) { pushStartMenu(); } return true; }
}

class Quadrant4MenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _view as Quadrant4View;
    function initialize(v as Quadrant4View) { Menu2InputDelegate.initialize(); _view = v; }
    function onSelect(item as WatchUi.MenuItem) as Void { 
        var id = item.getId();
        if (id.equals("start")) { _view.startNewGame(); WatchUi.popView(WatchUi.SLIDE_IMMEDIATE); } 
        else if (id.equals("settings")) {
            var sMenu = new WatchUi.Menu2({:title=>"Settings"});
            var soundEnabled = Storage.getValue("sound_enabled");
            var vibeEnabled = Storage.getValue("vibe_enabled");
            if (soundEnabled == null) { soundEnabled = true; }
            if (vibeEnabled == null) { vibeEnabled = true; }
            sMenu.addItem(new WatchUi.ToggleMenuItem("Sound", null, "sound", soundEnabled, null));
            sMenu.addItem(new WatchUi.ToggleMenuItem("Vibration", null, "vibration", vibeEnabled, null));
            WatchUi.pushView(sMenu, new Quadrant4SettingsDelegate(), WatchUi.SLIDE_IMMEDIATE);
        } else if (id.equals("about")) {
            WatchUi.pushView(new CreditsView(), new WatchUi.BehaviorDelegate(), WatchUi.SLIDE_UP);
        }
    }
    function onBack() as Void { WatchUi.popView(WatchUi.SLIDE_IMMEDIATE); System.exit(); }
}

class Quadrant4SettingsDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() { Menu2InputDelegate.initialize(); }
    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id.equals("sound")) { 
            Storage.setValue("sound_enabled", (item as WatchUi.ToggleMenuItem).isEnabled()); 
        } else if (id.equals("vibration")) {
            Storage.setValue("vibe_enabled", (item as WatchUi.ToggleMenuItem).isEnabled());
        }
    }
    function onBack() as Void { WatchUi.popView(WatchUi.SLIDE_IMMEDIATE); }
}

// --- DRAWABLES / ICONS ---

class PlayIcon extends WatchUi.Drawable {
    function initialize() { Drawable.initialize({}); }
    function draw(dc) {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE); dc.clear();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        var cx = dc.getWidth() / 2; var cy = dc.getHeight() / 2;
        dc.fillPolygon([[cx - 8, cy - 10], [cx - 8, cy + 10], [cx + 10, cy]]);
    }
}

class TrophyIcon extends WatchUi.Drawable {
    function initialize() { Drawable.initialize({}); }
    function draw(dc) {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE); dc.clear();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        var cx = dc.getWidth() / 2; var cy = dc.getHeight() / 2;
        dc.fillRectangle(cx - 8, cy - 8, 16, 10);
        dc.fillRectangle(cx - 2, cy + 2, 4, 6);
        dc.fillRectangle(cx - 6, cy + 8, 12, 2);
    }
}

class GearIcon extends WatchUi.Drawable {
    function initialize() { Drawable.initialize({}); }
    function draw(dc) {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE); dc.clear();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        var cx = dc.getWidth() / 2, cy = dc.getHeight() / 2, r = 12; 
        dc.fillPolygon([[cx-r/2, cy-r], [cx+r/2, cy-r], [cx+r, cy], [cx+r/2, cy+r], [cx-r/2, cy+r], [cx-r, cy]]);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE); dc.fillCircle(cx, cy, 4);
    }
}

class InfoIcon extends WatchUi.Drawable {
    function initialize() { Drawable.initialize({}); }
    function draw(dc) {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE); dc.clear();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        var cx = dc.getWidth() / 2; var cy = dc.getHeight() / 2;
        dc.setPenWidth(2); dc.drawCircle(cx, cy, 14);
        dc.drawText(cx, cy, Graphics.FONT_XTINY, "i", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}