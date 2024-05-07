#include <gba_console.h>
#include <gba_input.h>
#include <gba_interrupt.h>
#include <gba_systemcalls.h>
#include <gba_video.h>
#include <stdio.h>
#include <stdlib.h>

void clear_btn_line() {
	iprintf("\x1b[15;0H                              \n");
}

int main(void) {
	// the vblank interrupt must be enabled for VBlankIntrWait() to work
	// since the default dispatcher handles the bios flags no vblank handler
	// is required
	irqInit();
	irqEnable(IRQ_VBLANK);

	consoleDemoInit();

	// ansi escape sequence to set print co-ordinates
	// /x1b[line;columnH
	iprintf("\x1b[5;12HTestPad\n");

	// Change color to red using ANSI escape sequence
	// \x1b[31m sets the color to red
	// \x1b[0m resets the color
	iprintf("\x1b[10;9Hpisaucer.com\n");

	iprintf("\x1b[15;9HPress Any Key\n");

	while (1) {
		VBlankIntrWait();

		// Scan all the keys
		scanKeys();
		unsigned int keys = keysDown();

		if (keys & KEY_START) {
			clear_btn_line();
			iprintf("\x1b[15;7HSTART was pressed.\n");
		} else if (keys & KEY_SELECT) {
			clear_btn_line();
			iprintf("\x1b[15;6HSELECT was pressed.\n");
		} else if (keys & KEY_A) {
			clear_btn_line();
			iprintf("\x1b[15;9HA was pressed.\n");
		} else if (keys & KEY_B) {
			clear_btn_line();
			iprintf("\x1b[15;9HB was pressed.\n");
		} else if (keys & KEY_L) {
			clear_btn_line();
			iprintf("\x1b[15;9HL was pressed.\n");
		} else if (keys & KEY_R) {
			clear_btn_line();
			iprintf("\x1b[15;9HR was pressed.\n");
		} else if (keys & KEY_UP) {
			clear_btn_line();
			iprintf("\x1b[15;9HUP was pressed.\n");
		} else if (keys & KEY_DOWN) {
			clear_btn_line();
			iprintf("\x1b[15;7HDOWN was pressed.\n");
		} else if (keys & KEY_LEFT) {
			clear_btn_line();
			iprintf("\x1b[15;7HLEFT was pressed.\n");
		} else if (keys & KEY_RIGHT) {
			clear_btn_line();
			iprintf("\x1b[15;7HRIGHT was pressed.\n");
		}
	}
}
