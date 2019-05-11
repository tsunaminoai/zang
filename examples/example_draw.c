#include <SDL2/SDL.h>

static float drawbuf[640][2];
static int drawindex;

void plot(float min, float max) {
    drawbuf[drawindex][0] = min;
    drawbuf[drawindex][1] = max;
    if (++drawindex == 640) {
        drawindex = 0;
    }
}

void draw(SDL_Window *window, SDL_Surface *screen, const char *s) {
    static const char *font =
        "0000000044444040::000000::O:O::04N5>D?403C842IH02552E9F084200000"
        "84222480248884204E>4>E40044O440000000442000O00000000066000@84210"
        ">AIECA>0465444O0>A@@<3O0>A@<@A>0<:999O80O1?@@A>0>1?AAA>0OA@88440"
        ">AA>AA>0>AAAN@>000400400004004428421248000O0O000248@8420>AA84040"
        ">A@FEE>0>AAAOAA0?BB>BB?0>A111A>0?BBBBB?0O11O11O0O11O1110>A11IAN0"
        "AAAOAAA0>44444>0L8888960A95359A0111111O0AKKEEEA0ACCEIIA0>AAAAA>0"
        "?AAA?110>AAAE9F0?AAA?9A0>A1>@A>0O4444440AAAAAA>0AA:::440AAEEE::0"
        "AA:4:AA0AA:44440O@8421O0>22222>0001248@0>88888>04:A00000000000O0"
        "2480000000>@NA^011=CAA?000>A1A>0@@FIAAN000>AO1>0<22O222000^AAN@>"
        "11=CAAA04064444080<8888622B:6:B0644444<000?EEEE000?AAAA000>AAA>0"
        "00>AA?1100>AAN@@00=C111000N1>@?022O222<0009999F000AA::4000AEE::0"
        "00A:4:A000AA::4300O842O0H44244H04444444034484430002E800000000000";

    SDL_LockSurface(screen);
    {
        int pitch = screen->pitch >> 2;
        unsigned int *pixels = screen->pixels;
        {
            int h = 80;
            int i;
            for (i = 0; i < 640; i++) {
                float y0sample = -drawbuf[i][1] * 0.25f;
                float y1sample = -drawbuf[i][0] * 0.25f;
                int cy = 480 - h / 2 - 10;
                int y0limit = y0sample < -1.0f;
                int y1limit = y1sample > 1.0f;
                if (y0limit) y0sample = -1.0f;
                if (y1limit) y1sample = 1.0f;
                int y0 = cy + (int)(y0sample * h / 2);
                int y1 = cy + (int)(y1sample * h / 2);
                int y;
                int x = (i - drawindex + 640) % 640;
                for (y = cy - h / 2; y < y0; y++) {
                    pixels[y * pitch + x] = 0x18181818;
                }
                for (y = y0; y <= y1; y++) {
                    pixels[y * pitch + x] = 0x44444444;
                }
                for (y = y1 + 1; y <= 480 - 10; y++) {
                    pixels[y * pitch + x] = 0x18181818;
                }
                if (y0limit) {
                    y = cy - h / 2;
                    pixels[y * pitch + x] = 0xFFFF0000;
                }
                if (y1limit) {
                    y = cy + h / 2;
                    pixels[y * pitch + x] = 0xFFFF0000;
                }
                pixels[cy * pitch + x] = 0x66666666;
            }
        }
        {
            int x = 8, y = 8, ix = x;
            for (; *s; s++) {
                if (*s == '\n') {
                    x = ix; y += 20;
                } else if (*s >= 32) {
                    int index = (*s - 32) << 3, sx, sy;
                    for (sy = 0; sy < 16; sy++) {
                        for (sx = 0; sx < 16; sx++) {
                            if ((font[index + (sy >> 1)] - '0') & (1 << (sx >> 1))) {
                                pixels[(y + sy) * pitch + x + sx] = 0x88888888;
                            }
                        }
                    }
                    x += 16;
                }
            }
        }
    }
    SDL_UnlockSurface(screen);
    SDL_UpdateWindowSurface(window);
}