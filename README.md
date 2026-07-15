[![Silmaril](https://i.imgur.com/kBHYzRT.png)](https://ainuraudio.webflow.com/)

# AINUR SILMARIL 

##### **SILMARIL** is latest android audio modification installment in AINUR AUDIO series. Named after Silmarils - JRR Tolkien's legendarium light-embodying gems. **SILMARIL** stays true to its legendary namesake, encapsulating the luminous essence of sound: vivid, nuanced, rapid, grand & deeply emotional. Dedicated to bring high-fidelity true-res audio to a wide range of devices - **SILMARIL** adaptive design scales across various platforms, including Qualcomm, MediaTek, and Google Tensor, ensuring optimal audio output tailored to each device. Its ability to support an extensive range of playback options, ensures that whether you're using heaphones, external DACs, streaming services, or dedicated music player - music comes at an awe glory. **SILMARIL** elevates the audio experience to new heights, pushing boundaries and transforming the device into a vessel that sails through immersive sound waves.

> ### Dynamic Installer
> **SILMARIL** dynamically checks software/hardware environment context it's getting installed on to determine content to edit. This, further backed up by patches being corrected against respective sources, makes patching more accurate, as well as granular - feasible amount of patches is automatically adapted for the particular SOC/SDK/OEM case, building a solid foundation.

> ### UserOptions (UO)
> Useroptions were overhauled in **SILMARIL**. Expanded with more flags to experiment with and have a broader space for personal tinkering, whether universally, or for particular platform. Various UO lags were crosslinked with one-another, as well as with internal dynamic installer logic to offer a more robust experience. Additionally, debugging section added to provide comprehensive way to iterate through problematic installations.

> ### Connectivity
> **SILMARIL**'s variable patching approach opens up ability to support various playback connectivity types, including: internal speakers, usb-c, bluetooth and legacy 3.5 jack.

> ### AINULINDALE v2
> With AINULINDALE at its core, **SILMARIL** aims at eradicating the long lasting issue of android's forced up/down sampling bottleneck. By looping input rate to the output it effectively sets 1:1 native sampling for the OS and third-party apps that rely on it. Next, to make sampling fully transparent it increases temporal domain resolution by expanding the number of discrete points. This firmly secures signal's characteristics and transients, while exponentially dialing down quantization errors, phase distortion, temporal smearing & aliasing artifacts. Additionally, AINULINDALE improves buffer & memory allocation and switches sampler to UHQ state, getting rid of throttling jitter during FIR gen.
>
>The second-generation AINULINDALE engine sets a new benchmark for audio refinement. Embedded directly into the OS fundamentals of the audio pipeline - it rewrites how sound is processed, handled, and delivered. The result is a transparent, high-fidelity signal path that preserves the integrity of the original recording, ensuring every nuance of spatial imaging and harmonic detail is rendered with clinical accuracy and analog-like musicality:
>
>> Custom Double-Precision Bessel
>> 
>> Replacing truncated polynomials with a custom, double-precision Bessel engine, V2 achieves absolute machine epsilon convergence. This eliminates numerical rounding drift, resulting in a pristine windowing profile that preserves spatial imaging and harmonic detail by removing high-frequency artifacts entirely.
>>
>> High-Fidelity DC-Blocking
>> 
>> A real-time, single-pole IIR filter at the reverse format conversion layer eliminates DC offset across all bit depths. By using a fixed psychoacoustic pole constant, V2 maintains a pristine subsonic cutoff, ensuring total immunity against thread-local race conditions and jitter. The result is zero precision loss and phase-transparent, deep sub-bass.
>> 
>> TPDF Dither Engine
>> 
>> V2 introduces a mathematically pure TPDF dither engine to eliminate a correlated quantization distortion. By linearizing the process and employing a 2nd-order closed-loop error feedback network, the architecture shifts dither energy into the near-ultrasonic region. This renders bit-depth reductions transparent, allowing micro-details to resolve clearly.
>> 
>> Deferred Gain Staging
>> Traditional Android volume scaling destroys dynamic range by squashing signals early. V2 bypasses this by forcing unity gain through the mixer core, maintaining maximum bit-depth precision. Volume reduction is deferred to the final rendering stage and paired with noise-shaping. Shifting rounding errors to the ultrasonic spectrum preserves holographic depth and transient clarity, even at whisper-quiet levels.
>> 
>> Soft-Saturation Limiter
>> 
>> Replacing rigid brickwall limiting, V2 utilizes a 4-tap half-band polyphase interpolation filter for 2x-oversampled inter-sample peak tracking. Signals below -1.0 dBFS remain bit-perfect. When an overshoot occurs, the engine engages an analog tape-style transfer curve. This replaces jagged digital clipping with the warm, musical harmonics of vintage studio gear, eliminating aliasing and fatigue.


## Installation
* Flash module with `Magisk(Delta/Kitsune)/KernelSU/KernelSUNext/APatch/SukiSU` app. With ever growing number of forks and frequent changes to core logic - some root solutions might not work correctly.
* Initial install will place `UserOptions` file to `internal storage`. To experiment with extra options open `silmaril_useroptions` as text and follow instructions on what flags supposed to do and which values used. :exclamation: Reinstalling the module is vital for changes to take any effect. It is advised to uninstall & reinstall module, instead of flashing it over for some cases.


## Troubleshooting
In case experiencing any bugs - navigate to `UserOptions`'s `[Debug Section](https://github.com/Magisk-Modules-Repo/ainur_silmaril/blob/master/silmaril_useroptions#L753)` can be found. Follow its instructions to resolve the issue.


## Get in touch
* [Ainur Audio Pub Chat @ Telegram](https://t.me/ainuraudio)
* [Tech Kush Channel @ Telegram](https://t.me/android_og)
* [Ainur Audio @ XDA-Developers](https://forum.xda-developers.com/android/software/soundmod-ainur-audio-t3450516)


## Credits 
* [Magisk](https://github.com/topjohnwu/Magisk) | [KernelSU](https://github.com/tiann/KernelSU) | [APatch](https://github.com/bmax121/APatch)
* [MMT-Ex Template](https://github.com/Zackptg5/MMT-Extended/)
* [XMLStarlet](http://xmlstar.sourceforge.net)