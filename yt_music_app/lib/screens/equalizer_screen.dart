import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/equalizer_provider.dart';
import '../l10n/app_localizations.dart';

class EqualizerScreen extends StatelessWidget {
  const EqualizerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final eqProvider = Provider.of<EqualizerProvider?>(context);

    if (eqProvider == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: Text(l10n.eqTitle),
        ),
        body: Center(
          child: Text(
            'Equalizer not available',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final mediaQuery = MediaQuery.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF070202), // Deep volcanic black
        ),
        child: Stack(
          children: [
            // ── Background Ambient Fiery Glows ──

            // Top-right soft orange-red glow
            Positioned(
              top: -100,
              right: -100,
              width: 380,
              height: 380,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFED1C24).withOpacity(0.12),
                      blurRadius: 100,
                      spreadRadius: 20,
                    ),
                  ],
                ),
              ),
            ),

            // Bottom-left deep red-orange glow
            Positioned(
              bottom: -120,
              left: -100,
              width: 420,
              height: 420,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF15A24).withOpacity(0.12),
                      blurRadius: 120,
                      spreadRadius: 20,
                    ),
                  ],
                ),
              ),
            ),

            // Center molten gold glow (lights up the slider area)
            Positioned(
              bottom: 120,
              left: mediaQuery.size.width * 0.1,
              right: mediaQuery.size.width * 0.1,
              height: 300,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(150),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF9500).withOpacity(0.06),
                      blurRadius: 80,
                      spreadRadius: 20,
                    ),
                  ],
                ),
              ),
            ),

            // ── Main UI Layout ──
            SafeArea(
              child: Column(
                children: [
                  // ── Premium App Bar ──
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              l10n.eqTitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                                shadows: [
                                  Shadow(
                                    color: Colors.black54,
                                    offset: Offset(0, 2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Switch(
                          value: eqProvider.isEqualizerEnabled,
                          activeTrackColor: const Color(
                            0xFF9E0B0F,
                          ).withOpacity(0.3),
                          activeThumbColor: const Color(0xFFFF9500),
                          inactiveThumbColor: Colors.grey[600],
                          inactiveTrackColor: Colors.white.withOpacity(0.08),
                          onChanged: eqProvider.setEnabled,
                        ),
                      ],
                    ),
                  ),

                  // ── Content Panel ──
                  Expanded(
                    child: IgnorePointer(
                      ignoring: !eqProvider.isEqualizerEnabled,
                      child: AnimatedOpacity(
                        opacity: eqProvider.isEqualizerEnabled ? 1.0 : 0.35,
                        duration: const Duration(milliseconds: 300),
                        child: Column(
                          children: [
                            const SizedBox(height: 12),

                            // 🎨 Volcanic Glass Preset Selector
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Row(
                                children: eqProvider.presets.map((preset) {
                                  final isSelected =
                                      preset == eqProvider.selectedPreset;
                                  final label = _getPresetLabel(
                                    context,
                                    preset,
                                  );
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: GestureDetector(
                                      onTap: () => eqProvider.setPreset(preset),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 250,
                                        ),
                                        curve: Curves.easeInOut,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 22,
                                          vertical: 11,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            25,
                                          ),
                                          gradient: isSelected
                                              ? const LinearGradient(
                                                  colors: [
                                                    Color(0xFFED1C24),
                                                    Color(0xFFF15A24),
                                                    Color(0xFFFF9500),
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                )
                                              : null,
                                          color: isSelected
                                              ? null
                                              : Colors.white.withOpacity(0.03),
                                          border: Border.all(
                                            color: isSelected
                                                ? const Color(
                                                    0xFFFFCC00,
                                                  ).withOpacity(0.7)
                                                : Colors.white.withOpacity(
                                                    0.06,
                                                  ),
                                            width: 1.2,
                                          ),
                                          boxShadow: isSelected
                                              ? [
                                                  BoxShadow(
                                                    color: const Color(
                                                      0xFFFF6C00,
                                                    ).withOpacity(0.4),
                                                    blurRadius: 14,
                                                    spreadRadius: 1,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ]
                                              : [],
                                        ),
                                        child: Text(
                                          label,
                                          style: TextStyle(
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.white.withOpacity(
                                                    0.45,
                                                  ),
                                            fontWeight: isSelected
                                                ? FontWeight.w900
                                                : FontWeight.w600,
                                            fontSize: 13,
                                            letterSpacing: 0.5,
                                            shadows: isSelected
                                                ? [
                                                    const Shadow(
                                                      color: Colors.black26,
                                                      offset: Offset(0, 1),
                                                      blurRadius: 2,
                                                    ),
                                                  ]
                                                : [],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // 🎚 Studio-grade Fiery Equalizer Sliders
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: List.generate(
                                    eqProvider.bands.length,
                                    (index) => _buildSlider(
                                      context,
                                      eqProvider,
                                      index,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // ── "Lava Core" Bass Booster Card ──
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.03),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.06),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            // Dynamic Fire Icon
                                            AnimatedScale(
                                              scale:
                                                  1.0 +
                                                  (eqProvider.bassBoosterLevel /
                                                          100.0) *
                                                      0.25,
                                              duration: const Duration(
                                                milliseconds: 150,
                                              ),
                                              child: Icon(
                                                Icons.whatshot_rounded,
                                                color: Color.lerp(
                                                  const Color(
                                                    0xFFED1C24,
                                                  ).withOpacity(0.4),
                                                  const Color(0xFFFFD700),
                                                  eqProvider.bassBoosterLevel /
                                                      100.0,
                                                ),
                                                size: 22,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              l10n.eqBassBoost,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          '${eqProvider.bassBoosterLevel.round()}%',
                                          style: TextStyle(
                                            color: Color.lerp(
                                              const Color(0xFFED1C24),
                                              const Color(0xFFFFD700),
                                              eqProvider.bassBoosterLevel /
                                                  100.0,
                                            ),
                                            fontSize: 17,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.5,
                                            shadows: [
                                              Shadow(
                                                color: const Color(
                                                  0xFFED1C24,
                                                ).withOpacity(0.5),
                                                blurRadius: 10,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        activeTrackColor: Colors.transparent,
                                        inactiveTrackColor: Colors.transparent,
                                        trackHeight: 12,
                                        thumbColor: Colors.white,
                                        overlayColor: const Color(
                                          0xFFED1C24,
                                        ).withOpacity(0.2),
                                        thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius: 9,
                                          elevation: 4,
                                        ),
                                      ),
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          // Base track
                                          Container(
                                            height: 6,
                                            width: double.infinity,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF150A0A),
                                              borderRadius:
                                                  BorderRadius.circular(3),
                                            ),
                                          ),
                                          // Gradient active track
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: FractionallySizedBox(
                                              widthFactor:
                                                  eqProvider.bassBoosterLevel /
                                                  100.0,
                                              child: Container(
                                                height: 6,
                                                decoration: BoxDecoration(
                                                  gradient:
                                                      const LinearGradient(
                                                        colors: [
                                                          Color(0xFFED1C24),
                                                          Color(0xFFF15A24),
                                                          Color(0xFFFF9500),
                                                          Color(0xFFFFD700),
                                                        ],
                                                      ),
                                                  borderRadius:
                                                      BorderRadius.circular(3),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: const Color(
                                                        0xFFED1C24,
                                                      ).withOpacity(0.5),
                                                      blurRadius: 8,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          // Interactive transparent slider on top
                                          Slider(
                                            value: eqProvider.bassBoosterLevel,
                                            min: 0,
                                            max: 100,
                                            onChanged:
                                                eqProvider.setBassBoosterVisual,
                                            onChangeEnd:
                                                eqProvider.commitBassBooster,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider(
    BuildContext context,
    EqualizerProvider eqProvider,
    int index,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final List<String> bandLabels = [
      l10n.eqBandSubBass,
      l10n.eqBandBass,
      l10n.eqBandLowMid,
      l10n.eqBandMid,
      l10n.eqBandHighMid,
      l10n.eqBandTreble,
      l10n.eqBandBrilliance,
    ];

    final value = eqProvider.bandValues[index].clamp(-10.0, 10.0);
    final double percent = (value + 10.0) / 20.0;

    return Expanded(
      child: Column(
        children: [
          // ── Hz label ──
          Text(
            eqProvider.bands[index],
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          // ── dB value indicator ──
          Text(
            '${value > 0 ? "+" : ""}${value.toStringAsFixed(1)}',
            style: TextStyle(
              color: value == 0
                  ? Colors.white38
                  : value > 0
                  ? const Color(0xFFFFD700)
                  : const Color(0xFF8888FF),
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),

          // ── Slider Area with Custom Fire Track ──
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 1. Fiery Glowing Track Background (The Glass Column)
                Container(
                  width: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFF100706),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.04),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),

                // 2. Dynamic Molten Lava/Flame Filler
                Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: percent.clamp(0.02, 1.0),
                    child: Container(
                      width: 14,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: LinearGradient(
                          colors: value >= 0
                              ? const [
                                  Color(0xFF9E0B0F),
                                  Color(0xFFED1C24),
                                  Color(0xFFF15A24),
                                  Color(0xFFFF9500),
                                  Color(0xFFFFD700),
                                ]
                              : const [
                                  Color(0xFF1A1A3E),
                                  Color(0xFF3333AA),
                                  Color(0xFF5555CC),
                                ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: value >= 0
                                ? const Color(0xFFF15A24).withOpacity(0.3)
                                : const Color(0xFF5555CC).withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 2.5 Center line marker (0 dB reference)
                Positioned(
                  top: 0,
                  bottom: 0,
                  child: Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: 18,
                      height: 2,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ),

                // 3. Grid Lines (for that high-end studio gear feel)
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(7, (i) {
                    return Container(
                      width: 14,
                      height: 1,
                      color: Colors.white.withOpacity(0.12),
                    );
                  }),
                ),

                // 4. Interactive Transparent Slider overlay
                RotatedBox(
                  quarterTurns: 3,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.transparent,
                      inactiveTrackColor: Colors.transparent,
                      trackHeight: 18, // Make click target nice and wide
                      thumbColor: Colors.white,
                      overlayColor: const Color(0xFFFF9500).withOpacity(0.2),
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 10,
                        elevation: 5,
                        pressedElevation: 8,
                      ),
                    ),
                    child: Slider(
                      value: value,
                      min: -10,
                      max: 10,
                      onChanged: (val) =>
                          eqProvider.setBandValueVisual(index, val),
                      onChangeEnd: (val) =>
                          eqProvider.commitBandValue(index, val),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Band name label ──
          Text(
            bandLabels[index],
            style: TextStyle(
              color: percent > 0.5
                  ? Color.lerp(
                      const Color(0xFFF15A24),
                      const Color(0xFFFFD700),
                      (percent - 0.5) * 2,
                    )
                  : Color.lerp(
                      const Color(0xFF993333),
                      const Color(0xFFF15A24),
                      percent * 2,
                    ),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _getPresetLabel(BuildContext context, String preset) {
    final l10n = AppLocalizations.of(context)!;
    switch (preset) {
      case 'normal':
        return l10n.eqPresetNormal;
      case 'pop':
        return l10n.eqPresetPop;
      case 'classic':
        return l10n.eqPresetClassic;
      case 'jazz':
        return l10n.eqPresetJazz;
      case 'rock':
        return l10n.eqPresetRock;
      case 'custom':
        return l10n.eqPresetCustom;
      default:
        return preset;
    }
  }
}
