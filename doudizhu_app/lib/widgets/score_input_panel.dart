import 'package:flutter/material.dart';
import '../models/player.dart';
import '../utils/score_calculator.dart';

class ScoreInputPanel extends StatefulWidget {
  final List<Player> sessionPlayers;
  final void Function({
    required String landlordId,
    required List<String> farmerIds,
    required bool isLandlordWin,
    required bool spring,
    required bool blind,
    required int kickCount,
    required String? kickFarmerId,
    required int bombCount,
  }) onSubmit;

  const ScoreInputPanel({
    super.key,
    required this.sessionPlayers,
    required this.onSubmit,
  });

  @override
  State<ScoreInputPanel> createState() => _ScoreInputPanelState();
}

class _ScoreInputPanelState extends State<ScoreInputPanel> {
  String? _landlordId;
  bool _isLandlordWin = true;
  bool _spring = false;
  bool _blind = false;
  int _kickCount = 0;
  String? _kickFarmerId;
  int _bombCount = 0;

  List<Player> get _farmers =>
      widget.sessionPlayers.where((p) => p.id != _landlordId).toList();

  int get _nTotal => (_spring ? 1 : 0) + (_blind ? 1 : 0) + _kickCount + _bombCount;

  int get _previewScore {
    if (_landlordId == null) return 0;
    return calculateBaseScore(_nTotal);
  }

  void _reset() {
    setState(() {
      _landlordId = null;
      _isLandlordWin = true;
      _spring = false;
      _blind = false;
      _kickCount = 0;
      _kickFarmerId = null;
      _bombCount = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1C1410),
            Color(0xFF2A1F18),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF8B6914), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 地主选择
          _sectionLabel('地主'),
          const SizedBox(height: 6),
          Row(
            children: widget.sessionPlayers.map((p) {
              final selected = _landlordId == p.id;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() { _landlordId = p.id; _kickFarmerId = null; }),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      gradient: selected ? const LinearGradient(
                        colors: [Color(0xFFC41E1E), Color(0xFFE53935)],
                      ) : null,
                      color: selected ? null : const Color(0xFF1C1410),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected ? const Color(0xFFC4952A) : const Color(0xFF8B6914),
                        width: selected ? 2 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(p.name, style: TextStyle(
                      color: selected ? const Color(0xFFF5E6C8) : const Color(0xFF8B7355),
                      fontWeight: FontWeight.bold,
                    )),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // 赢/输
          _sectionLabel('结果'),
          const SizedBox(height: 6),
          Row(
            children: [
              _resultBtn('地主赢', _isLandlordWin, const Color(0xFFE53935), () => setState(() => _isLandlordWin = true)),
              const SizedBox(width: 8),
              _resultBtn('地主输', !_isLandlordWin, const Color(0xFF4CAF50), () => setState(() => _isLandlordWin = false)),
            ],
          ),
          const SizedBox(height: 12),

          // 加倍项
          _sectionLabel('加倍项'),
          const SizedBox(height: 6),
          Row(
            children: [
              _toggleBtn('春天', _spring, () => setState(() => _spring = !_spring)),
              const SizedBox(width: 6),
              _toggleBtn('蒙牌', _blind, () => setState(() => _blind = !_blind)),
            ],
          ),

          // 踢
          if (_landlordId != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('踢：', style: TextStyle(color: Color(0xFF8B7355), fontSize: 13)),
                ..._farmers.map((f) {
                  final selected = _kickFarmerId == f.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => setState(() {
                        if (selected) { _kickFarmerId = null; _kickCount = 0; }
                        else { _kickFarmerId = f.id; _kickCount = 1; }
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: selected ? const LinearGradient(
                            colors: [Color(0xFFC41E1E), Color(0xFFE53935)],
                          ) : null,
                          color: selected ? null : const Color(0xFF1C1410),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: selected ? const Color(0xFFC4952A) : const Color(0xFF8B6914),
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Text(f.name, style: TextStyle(color: selected ? const Color(0xFFF5E6C8) : const Color(0xFF8B7355), fontSize: 13)),
                      ),
                    ),
                  );
                }),
                if (_kickFarmerId != null) ...[
                  const SizedBox(width: 6),
                  _toggleBtn('踢', _kickCount >= 1, () => setState(() => _kickCount = 1)),
                  const SizedBox(width: 4),
                  _toggleBtn('踢+反踢', _kickCount >= 2, () => setState(() => _kickCount = 2)),
                ],
              ],
            ),
          ],

          // 炸弹
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('炸弹：', style: TextStyle(color: Color(0xFF8B7355), fontSize: 13)),
              const SizedBox(width: 4),
              _countBtn(Icons.remove, _bombCount > 0, () => setState(() => _bombCount--)),
              Container(
                width: 36, height: 36,
                alignment: Alignment.center,
                child: Text('$_bombCount', style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              _countBtn(Icons.add, _bombCount < 8, () => setState(() => _bombCount++)),
            ],
          ),
          const SizedBox(height: 14),

          // 分数预览
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFFC41E1E).withOpacity(0.2), const Color(0xFFE53935).withOpacity(0.1)],
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFC4952A), width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('本局 ', style: TextStyle(color: Color(0xFF8B7355))),
                Text('$_previewScore', style: const TextStyle(
                  color: Color(0xFFFFD54F), fontSize: 32, fontWeight: FontWeight.bold, height: 1,
                )),
                const Text(' 分', style: TextStyle(color: Color(0xFF8B7355))),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 确认按钮
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _landlordId != null ? _submit : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFC41E1E),
                foregroundColor: const Color(0xFFF5E6C8),
              ),
              child: const Text('确认记分'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text, style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 12, fontWeight: FontWeight.bold));
  }

  Widget _resultBtn(String text, bool active, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: active ? LinearGradient(
              colors: [color, color.withOpacity(0.8)],
            ) : null,
            color: active ? null : const Color(0xFF1C1410),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active ? color.withOpacity(0.8) : const Color(0xFF8B6914),
              width: active ? 2 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(text, style: TextStyle(
            color: active ? const Color(0xFFF5E6C8) : const Color(0xFF8B7355),
            fontWeight: FontWeight.bold,
          )),
        ),
      ),
    );
  }

  Widget _toggleBtn(String text, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          gradient: active ? const LinearGradient(
            colors: [Color(0xFFC41E1E), Color(0xFFE53935)],
          ) : null,
          color: active ? null : const Color(0xFF1C1410),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active ? const Color(0xFFC4952A) : const Color(0xFF8B6914),
            width: active ? 2 : 1,
          ),
        ),
        child: Text(text, style: TextStyle(
          color: active ? const Color(0xFFF5E6C8) : const Color(0xFF8B7355),
          fontSize: 13,
          fontWeight: active ? FontWeight.bold : FontWeight.normal,
        )),
      ),
    );
  }

  Widget _countBtn(IconData icon, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1410),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled ? const Color(0xFFC4952A) : const Color(0xFF8B6914),
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: enabled ? const Color(0xFFFFD54F) : const Color(0xFF8B7355), size: 20),
      ),
    );
  }

  void _submit() {
    if (_landlordId == null) return;
    final farmerIds = widget.sessionPlayers
        .where((p) => p.id != _landlordId)
        .map((p) => p.id)
        .toList();

    widget.onSubmit(
      landlordId: _landlordId!,
      farmerIds: farmerIds,
      isLandlordWin: _isLandlordWin,
      spring: _spring,
      blind: _blind,
      kickCount: _kickCount,
      kickFarmerId: _kickFarmerId,
      bombCount: _bombCount,
    );
    _reset();
  }
}
