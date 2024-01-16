pub const fonts = struct {
    pub const roboto_regular = @embedFile("fonts/Roboto-Regular.ttf");
    pub const roboto_bold = @embedFile("fonts/Roboto-Bold.ttf");
};

pub const images = struct {
    pub const blendmodealpha = @embedFile("images/blendmodealpha.png");
    pub const blendmodereplace = @embedFile("images/blendmodereplace.png");
};

pub const palettes = struct {
    pub const arne16 = @embedFile("palettes/arne16.pal");
};
