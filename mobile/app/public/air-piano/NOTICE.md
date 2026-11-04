# Hand gesture instrument credits

Handtracking Piano by Parinith Reddy: https://github.com/parinith-web/Handtracking-Piano
Pinned original piano commit: 1683538cbe06b6088719789571396a7062fee2a6. Author declares MIT in the original README; existing attributions retained.

Gesture Synth by Eric Wei: https://github.com/ericwei97-cloud/gesture-synth
Pinned guitar logic commit: 7ee25ba8c30f0a0cf544835a2dae199e4b7b9484.
Educational/non-commercial adaptation; retain attribution. Commercial use requires the author's permission. The independent LICENSE controls this adaptation; the upstream package.json ISC label is not used to remove those restrictions.
See GESTURE_SYNTH_LICENSE.txt and GESTURE_SYNTH_UPSTREAM.json.

The app uses its existing offline MediaPipe Hands runtime. Original online analytics and browser synthesis are not executed. Hand gestures send note/control packets to the FPGA. Guitar octave voicing fits the fixed E2–B4 hardware range; right-hand tilt controls the FPGA's available reverb, rather than the original Web Audio filter.
