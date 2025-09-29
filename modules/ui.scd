~createUI = {
    var window;

    var applyDarkStyle = { |view|
        view.background_(Color.black).stringColor_(Color.white);
    };



    // --- Layout ---
    window.layout_(
    )

    window.onClose = { window.close; freqscope.kill };
    window.front;
};

~createUI.value;
