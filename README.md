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
>The second-generation AINULINDALE engine redefines Android's audio pipeline at the system level, replacing core processing stages with mathematically refined implementations designed to preserve precision from decoding to final output. Every component is engineered to minimize numerical error, maintain phase integrity, and deliver a transparent, natural presentation that stays faithful to the original recording.:
>
>> Custom Double-Precision Bessel by James34602
>> 
>> A custom double-precision Bessel implementation replaces the original truncated approximation used during FIR coefficient generation. By converging to machine precision, the Kaiser window is generated with significantly lower numerical error, producing more accurate filter coefficients and improved stop-band performance for cleaner resampling.
>>
>> High-Fidelity DC-Blocking
>> 
>> A real-time single-pole DC blocker removes DC offset immediately after integer-to-float conversion across every supported PCM format. Internal double-precision filter states preserve long-term accuracy while an ultra-low cutoff frequency maintains complete transparency throughout the audible spectrum, including the deepest sub-bass.
>> 
>> TPDF Dither Engine
>> 
>> A mathematically correct TPDF dither engine combined with second-order noise shaping minimizes correlated quantization distortion during bit-depth reduction. Dither energy is shifted toward ultrasonic frequencies, allowing low-level detail and ambience to remain perceptually intact without introducing harsh digital artifacts.
>> 
>> Deferred Gain Staging
>> 
>> Instead of attenuating audio before processing, SILMARIL maintains unity gain throughout the DSP pipeline and applies user volume only at the final rendering stage. Preserving full internal signal resolution allows subsequent processing to operate with maximum numerical precision while reducing rounding error during low-volume playback.
>> 
>> Soft-Saturation Limiter
>> 
>> A true-peak-aware limiter uses 2x oversampling with polyphase interpolation to detect inter-sample peaks before they reach the output stage. Audio below the limiting threshold passes transparently, while genuine overshoots are controlled using a smooth saturation curve that avoids the harsh artifacts associated with conventional brickwall limiting.


## Installation
* Flash module with `Magisk(Delta/Kitsune)/KernelSU/KernelSUNext/APatch/SukiSU` app. With ever growing number of roots/metamodules as well as their forks, along with frequent changes to their core logic - `some root/mounting solutions might not work correctly`.
* Initial install will place `UserOptions` file to `internal storage`. To experiment with extra options open `silmaril_useroptions` as text and follow instructions on what flags supposed to do and which values used. :exclamation: Reinstalling the module is vital for changes to take any effect. It is advised to uninstall & reinstall module, instead of flashing it over for some cases.


## Troubleshooting
In case experiencing any bugs - navigate to `UserOptions`'s [Debug Section](https://github.com/Magisk-Modules-Repo/ainur_silmaril/blob/master/silmaril_useroptions#L753) can be found. Follow its instructions to resolve the issue.


## Get in touch
* [Ainur Audio Pub Chat @ Telegram](https://t.me/ainuraudio)
* [Tech Kush Channel @ Telegram](https://t.me/android_og)
* [Ainur Audio @ XDA-Developers](https://forum.xda-developers.com/android/software/soundmod-ainur-audio-t3450516)


## Credits 
* [Magisk](https://github.com/topjohnwu/Magisk) | [KernelSU](https://github.com/tiann/KernelSU) | [APatch](https://github.com/bmax121/APatch)
* [MMT-Ex Template](https://github.com/Zackptg5/MMT-Extended/)
* [XMLStarlet](http://xmlstar.sourceforge.net)