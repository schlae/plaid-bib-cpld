# The Plaid Bib CPLD edition - an Ad Lib MCA Clone

The Plaid Bib is a 100% compatible clone of the Ad Lib MCA sound card. This is
an Ad Lib card designed for Micro Channel Architecture machines, such as the
IBM PS/2 family and other compatibles from NCR, Tandy, Dell, and others.

![Plaid Bib photo, CPLD edition](https://github.com/schlae/plaid-bib-cpld/blob/master/images/PlaidBibCPLD.jpg)

Here are the design files. The BOM includes Mouser Electronics part numbers for
everything except for the YM3812 and the Y3014B, both of which are available
from brokers in China such as UTSource.

[Schematic](https://github.com/schlae/plaid-bib-cpld/blob/master/PlaidBibCPLD.pdf)

[Bill of Materials](https://github.com/schlae/plaid-bib-cpld/blob/master/PlaidBibCPLD.csv)

[Fab Files](https://github.com/schlae/plaid-bib-cpld/blob/master/fab/PlaidBibCPLD-fab.zip)

The logic family used for U1 is critical. Do not substitute LS, HC, HCT, or
similarly slow logic families. Use ALS, ACT, AHCT, or even F.

It's a good idea to use sockets for all the DIP chips just in case you need
to swap parts out.

## CPLD Notes
The Plaid Bib uses a CPLD (Complex Programmable Logic Device) to interface
between the MCA bus and the YM3812 synthesizer chip. Compared with the original
design that uses the 82C611 interface chip, this version is much simpler and
incorporates much of the external logic into a single device.

The CPLD must be programmed with the bitstream before you can use the card.
[You can find the bitstream here.](https://github.com/schlae/plaid-bib-cpld/blob/master/cpld/mcadlib.jed)

I've had good luck using the Linux command line program 'xc3sprog' with a
FTDI FT2232H Mini Module [datasheet here](https://www.ftdichip.com/Support/Documents/DataSheets/Modules/DS_FT2232H_Mini_Module.pdf).

Wiring for the FT2232H mini module:

| Point 1    | Point 2          | Description           |
| ---------- | ---------------- | --------------------- |
| CN2 pin 1  | CN2 pin 11       | V3V3 to VIO strap     |
| CN3 pin 1  | CN3 pin 3        | VBUS to VCC strap     |
| CN2 pin 3  | CN3 pin 12       | V3V3 to VIO strap (2) |
| CN2 pin 5  | JTAG cable pin 6 | V3V3 to Plaid Bib (optional) |
| CN2 pin 2  | JTAG cable pin 5 | GND                   |
| CN2 pin 7  | JTAG cable pin 4 | AD0, aka TCK          |
| CN2 pin 9  | JTAG cable pin 3 | AD2, aka TDO          |
| CN2 pin 10 | JTAG cable pin 2 | AD1, aka TDI          |
| CN2 pin 12 | JTAG cable pin 1 | AD3, aka TMS          |

You need to provide external power to the Plaid Bib through the 3.3V wire on the
programming header. The optional wire does this, or you can use a bench supply.

I obtained xc3sprog [here](https://github.com/matrix-io/xc3sprog). You can
compile and run this program on a Raspberry Pi using the Pi GPIO lines instead
of the FTDI mini module. In my case, I chose to patch it (TBD) to remove
references to the Pi GPIO library and ran it on a regular Linux PC.

Using the FTDI mini module, programming is quite simple. Connect the cable to
the assembled Plaid Bib board, then run the following command.

`xc3sprog -c ftdi -v mcadlib.jed`

If you run into issues with the cable not being detected, check your udev rules.
In theory you could run xc3sprog as root, but that's bad practice. ;)

### Building the CPLD Project
If you're feeling particularly masochistic, you can try building the CPLD
project using the Xilinx ISE Webpack tools. Because the ISE Webpack only
supports Ubuntu 14.7, it's simplest to run the program from a Docker container.
I use [docker-xilinx](https://github.com/jimmo/docker-xilinx).

### How the CPLD Works
This isn't meant to be an exhaustive tutorial on how Micro Channel bus works,
but here are a few basic functions the CPLD provides:
- Card setup and POS (programmable option select)
- Address decoding logic
- MCA bus logic interface to the YM3812
- A clock divider to provide 3.57MHz to the YM3812

Each card implements several 8-bit registers (POS registers). Two of these
registers are fixed and implement the 16-bit card ID value, which is how the
BIOS and the reference disk software identify the card. The remaining POS
registers can be used for any configuration-related function and are designed
to replace configuration jumpers. The meanings of each register bit are up
to the card designer, with the exception of a reserved bit that is used by
the BIOS to enable or disable a card; this way, the BIOS can resolve conflicts
automatically. Typically POS register bits control IO and memory address
assignments, IRQ lines, and so forth.

The CPLD implements the two required ID registers as well as two additional
POS registers. The first contains only a single bit -- the card enable signal.
The second register programs bits [8:4] of the I/O address. This should always
be 0xC0 so that the card appears at 0x388/0x389.

When you add a new card to a MCA bus system, the BIOS detects the new card
and requires you to run the reference disk configuration program. This program
searches for an ADF file associated with the new card. The ADF file is
human-readable text that tells the BIOS which I/O address, IRQ, etc match up
with each POS register bit. The reference disk program uses this information to
find a configuration for all the cards in the computer so that none of them
conflict with each other. When it's done, it writes the raw POS register values
along with the card ID values to the battery-backed SRAM on the motherboard.

The CPLD decodes the I/O address (0x388 and 0x389) to ensure the card only
responds when it is addressed directly by the computer. On the MCA bus, the
address lines and control lines (s0 and s1 aka write and read) get latched
on the falling edge of the ADL# (address latch) control line.

The data transfer itself begins a little later with the falling edge of the
CMD# control line and ends with rising edge. MCA pipelines address and data;
during the data transfer, the MCA prepares the address for the next bus
transfer! The CPLD turns these signals into the typical asynchronous transfer
used by the YM3812.

Finally, the CPLD takes the MCA bus 14.3MHz clock signal and divides it by 4
to get the 3.57MHz clock used by the YM3812.

## Bracket
MCA brackets are no longer available. You have a few options:
- Remove the bracket from an existing card, like a token ring card or something
- 3D print the bracket
- Use the card without a bracket at all

If you want to print your own, here are STEP models of the bracket and the
plastic clip.

[Bracket](https://github.com/schlae/plaid-bib/blob/master/mech/MCABracket.STEP)

[Clip](https://github.com/schlae/plaid-bib/blob/master/mech/MCAClip.STEP)

Please note that neither file is designed specifically for 3D printing; they're
meant to match the real hardware exactly. The clip might print just fine, but
the bracket is probably too thin to print well.

## Compatibility
The Plaid Bib has been tested on some models of PS/2. More to be added as
people provide test reports.

| Computer           | Model    | CPU          | Adapters | Compatible ? |
| ------------------ | -------- | ------------ | -------- | ------------ |
| IBM PS/2 Model 50  | 8550-021 | 80286-10     | | Partial�
| IBM PS/2 Model 50Z | 8550-031 | 80286-10     | Hard disk (ID:DF9F), IBM SCSI 71G3575 | Yes |
| IBM PS/2 Model 55SX with Reply Turboboard| 8555 | 486SLC2-50 |  | Yes |
| IBM PS/2 Model 70  | 8570-E61 | 386-16   | Adaptec AHA-1640 | Yes |
| IBM PS/2 Model 70  | 8570-121 | 386-20   | | Yes |
| IBM PS/2 Model 80  | 8580-071 | 386DX-16   | | Yes� |
| IBM PS/2 Model 85  | 9585     | 486SX-33     | | Yes |
| IBM PS/2 Model 95  | 8595     | 486DX2-50    | | Yes |

�One user reported compatibility problems with the hard drive (ID:DF9F)

�PS/2 Model 80 machines with the type 1 planar (16MHz 386) and an installed
MCA memory card may have compatibility issues; the Plaid Bib behaves
erratically in one user's machine, but works fine in another one.

## Installation
You will need the ADF (adapter description file) in order to set up the Plaid
Bib on your MCA computer.

[Plaid Bib ADF](https://github.com/schlae/plaid-bib/blob/master/@70D7.ADF)

Place the file on a 3 1/2" floppy disk. After you install the card and boot
the computer, it will detect that a new card has been installed and prompt
you to insert the reference disk. Do this and follow the prompts. When the
setup utility asks you to insert the option disk, use the one that contains
the ADF file. After the setup utility configures the card, it will prompt
you to reboot the machine.

Once that's finished, try out the Plaid Bib with your favorite game!

## Troubleshooting
Keep in mind that Micro Channel systems can be difficult to troubleshoot due to
the large number of possible configurations and the varied implementations of
the bus. Not all games will even work on some PS/2 systems, even without a
sound card!

Here are a few things to try out first before you really start digging in:
- Is the CPLD soldered in correctly, with no solder bridges? If you have a
microscope, check every solder joint! Did you program the CPLD?
- Are there any bad or fake chips? Some users have reported issues with fake
74ALS245 buffer chips, fake YM3812s, and fake Y3014B chips
- Try running [SBDIAG](https://github.com/schlae/snark-barker/tree/master/sbdiag)

### Symptom-by-Symptom

**Computer will not boot at all, Computer boots but does not detect the card**

Suspect the CPLD. Check for bad solder joints. Is pin 1 oriented correctly?
Compare it with the photo.

Did you use something other than a 74ALS245, 'ACT245, 'AHCT245, or 'F245?
Slower logic families can "crash the bus" and prevent the system from booting.

**The card causes random errors with the hard disk, or with other cards**

Did you buy a legitimate 74ALS245, or is it a fake? Try swapping it out.

## License
This work is licensed under a Creative Commons Attribution-ShareAlike 4.0
International License. See [https://creativecommons.org/licenses/by-sa/4.0/](https://creativecommons.org/licenses/by-sa/4.0/).
