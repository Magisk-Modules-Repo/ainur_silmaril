# Changelog

## [19.05] - `2025-12-27`
Initial release
### Installer
- Various installer qoa improvements & fixes
- Staged & dynamic hw/sw/env detection
### General
- AINULINDALE true-res audio
- Studio quality transparent sampling
- Fully attenuated volume curve
- Revised SFX cleanup
- Various policy patches
- Various blob patches
- Various OEM patches
- UO debug section
### Qualcomm
- All platforms HAL/ARE interfaces setup
- Extended codec bitwidth & samplerate setup
- Revised per platform dynamic mixer patching:
  - codec analog & digital gain picker
  - codec bluetooth samplerate picker
  - split compander for spk & hph
- Extended framebuffer setup
- Hw dsp offload disabler
- Hw dsp bitwidth picker
- Disabled Peak-to-range compression
- Disabled HPF / Biquads support
- Speaker multi-band drc disabler
- Full Vrms for 3.5 devices
- Selected platforms native dejitter & pmclk enabler
- Selected platforms HAL init params patches
- Selected platforms buffer patch
### Google Tensor
- AOC configuration patching
- AOC mixer patching
- Extended framebuffer setup
- Tensor codec samplerate & bitwidth setup
- Experimental aoc patch
- Experimental spk sfx disabler
### Mediatek
- HAL config setup
- HQA mode
- Forced ljitter clk
- Edits in MTK mixer patching
