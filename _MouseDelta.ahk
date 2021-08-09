; ===============================================
; === Example ===================================
; ===============================================

g := Gui("+AlwaysOnTop 0x2000000 +OwnDialogs","MouseDelta") ; 0x2000000 = double buffering, less flicker of controls
g.OnEvent("close",gui_close)

ctl := g.Add("text","w300 h300 vMyEdit ReadOnly","Move the mouse or click a button")
ctl.SetFont("s10","Consolas")
g.Add("Button","xm w150 vStart","Start").OnEvent("click",ctl_events)
g.Add("Button","x+0 w150 vStop","Stop").OnEvent("click",ctl_events)
g.Show()

ctl_events(ctl, info) {
    If (ctl.name = "Start") {
        ctl.gui.md.Start()
        ctl.gui["MyEdit"].Text := "LastError: " ctl.gui.md.LastError
    } Else If (ctl.name = "Stop") {
        ctl.gui.md.Stop()
        ctl.gui["MyEdit"].Text := "LastError: " ctl.gui.md.LastError
    }
}


gui_close(g) {
    Global md
    If md.state
        md.Stop()
    ExitApp
}

md := MouseDelta(MouseEvent)
g.md := md

md.SetState(1)

MouseEvent(md, MouseID, obj) { ; parameters for callback function
    Global g
    
    msg := "LastError: " md.LastError "`r`n`r`n"
         . "MouseID: " Format("0x{:X}",MouseID) "`r`n"
         . "x/y: " obj.x ", " obj.y "`r`n"  ; all obj propertes are displayed here
         . "x/y Delta: " obj.xD " / " obj.yD "`r`n"
         . "  LButton: " obj.b1 "`r`n"
         . "  RButton: " obj.b2 "`r`n"
         . "  MButton: " obj.b3 "`r`n"
         . " XButton1: " obj.b4 "`r`n"
         . " XButton2: " obj.b5 "`r`n"
         . "    Wheel: " obj.mw "`r`n"
    
    g["MyEdit"].value := msg
}

; ======================================================================
; MouseDelta class
;   Originally by evilC writen for AHK v1
;   https://www.autohotkey.com/boards/viewtopic.php?f=19&t=10159&hilit=mousedelta
; ======================================================================
Class MouseDelta {
    State := 0
    DevSize := 8 + A_PtrSize
    devMult := 1
    LastError := 0
    RAWINPUTDEVICE := Buffer(this.DevSize * this.devMult)
    
    __New(callback) {
        this.MouseMovedFn := ObjBindMethod(this,"MouseMoved")
        , this.Callback := callback
    }

    Start() {
        Static RIDEV_INPUTSINK := 0x00000100 ; Register mouse for WM_INPUT messages.
        
        RAWINPUT_GUI := Gui()           ; WM_INPUT needs a hwnd to route to, so get the hwnd of the AHK Gui.
        RAWINPUT_GUI.Opt("ToolWindow")
        RAWINPUT_GUI.Show()             ; window must be shown apparently ...
        this.gui := RAWINPUT_GUI
        
        NumPut("UShort",1,"UShort",2,"UInt",RIDEV_INPUTSINK,"UPtr",RAWINPUT_GUI.hwnd, this.RAWINPUTDEVICE.ptr) ; populate RAWINPUTDEVICE
        
        result := DllCall("RegisterRawInputDevices", "UPtr", this.RAWINPUTDEVICE.Ptr, "UInt", this.devMult, "UInt", this.DevSize )
        this.LastError := A_LastError
        
        OnMessage(0x00FF, this.MouseMovedFn)
        this.State := 1
        return this    ; allow chaining
    }
    
    Stop() {
        static RIDEV_REMOVE := 0x00000001
        OnMessage(0x00FF, this.MouseMovedFn, 0)
        
        NumPut("UInt", RIDEV_REMOVE, "UPtr", 0, this.RAWINPUTDEVICE, 4)
        
        DllCall("RegisterRawInputDevices", "UPtr", this.RAWINPUTDEVICE.Ptr, "UInt", this.devMult, "UInt", this.DevSize)
        this.LastError := A_LastError
        
        this.gui.Destroy()
        this.State := 0
        return this    ; allow chaining
    }
    
    SetState(state) {
        if (state && !this.State)
            this.Start()
        else if (!state && this.State)
            this.Stop()
        return this    ; allow chaining
    }

    Delete() {
        this.Stop()
        this.MouseMovedFn := ""
    }
    
    MouseMoved(wParam, lParam, msg, hwnd) { ; Called when the mouse moved and get raw input stats.
        Critical
        Static headerSz   := 2 * A_PtrSize
        Static pcbSize    := 8 + headerSz
        Static uRawInput  := {ptr:0}, structSize := 0
        
        header := Buffer(pcbSize, 0) ; Get hDevice from RAWINPUTHEADER to identify which mouse this data came from
        If !DllCall("GetRawInputData", "UPtr", lParam, "uint", 0x10000005
                                     , "UPtr", header.ptr, "Uint*", &pcbSize, "Uint", pcbSize) {
            this.LastError := A_LastError
            Return 0
        }
        
        hwID := NumGet(header, 8, "UPtr")
        
        If !structSize
            structSize := NumGet(header, 4, "UInt")
          , uRawInput := Buffer(structSize)
        
        r := DllCall("GetRawInputData", "UInt", lParam, "UInt", 0x10000003               ; Get RawInput data
                                      , "UPtr", uRawInput.ptr, "UInt*", &structSize, "UInt", 8 + headerSz)
        this.LastError := A_LastError
        
        Static mFlags_off   := 12+headerSz, mData_off := 14+headerSz
             , mXd_off      := 20+headerSz, mYd_off   := 24+headerSz
             , mExtra_off   := 28+headerSz
        Static b1 := 0, b2 := 0, b3 := 0, b4 := 0, b5 := 0, mw := 0
        
        flags := NumGet(uRawInput, mFlags_off, "UShort")    ; +12
        data  := NumGet(uRawInput, mData_off, "Short")      ; +14
        
        (flags & 0x1)   ? b1 := true : (flags & 0x2)   ? b1 := false : ""
        (flags & 0x4)   ? b2 := true : (flags & 0x8)   ? b2 := false : ""
        (flags & 0x10)  ? b3 := true : (flags & 0x20)  ? b3 := false : ""
        (flags & 0x40)  ? b4 := true : (flags & 0x80)  ? b4 := false : ""
        (flags & 0x100) ? b5 := true : (flags & 0x200) ? b5 := false : ""
        (flags & 0x400) ? (mw := data) : (mw := 0) ; mouse wheel delta
        
        xD := NumGet(uRawInput, mXd_off, "Int") ; x Delta
        yD := NumGet(uRawInput, mYd_off, "Int") ; y Delta
        
        POINT := Buffer(8,0)
        DllCall("GetCursorPos","UPtr",POINT.ptr)
        x := NumGet(POINT,"UInt")
        y := NumGet(POINT,4,"UInt")
        
        obj := {x:x, y:y, xD:xD, yD:yD
              , b1:b1, b2:b2, b3:b3, b4:b4, b5:b5, mw:mw}
        
        this.callback(hwID, obj)
    }
}


dbg(_in) {
    OutputDebug "AHK: " _in
}