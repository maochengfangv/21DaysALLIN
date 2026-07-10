import { StyleSheet } from 'react-native';

export const demoStyles = StyleSheet.create({
  catalogList: { gap: 10 },
  catalogItem: {
    borderRadius: 12,
    backgroundColor: '#F8FAFC',
    padding: 12,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: '#E2E8F0',
  },
  catalogTitle: { fontSize: 15, fontWeight: '700', color: '#0F172A' },
  catalogSubtitle: { fontSize: 12, color: '#475569', marginTop: 4 },
  buttonGroup: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  resultText: { fontSize: 13, lineHeight: 19, color: '#334155' },
  errorText: { fontSize: 13, lineHeight: 19, color: '#DC2626' },
  childCard: {
    marginTop: 8,
    borderRadius: 12,
    backgroundColor: '#F8FAFC',
    padding: 12,
    gap: 8,
  },
  childTitle: { fontSize: 14, fontWeight: '700', color: '#0F172A' },
  listContent: { paddingBottom: 24, gap: 10 },
  listItem: {
    backgroundColor: '#fff',
    borderRadius: 14,
    padding: 12,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: '#E2E8F0',
    flexDirection: 'row',
    gap: 12,
    alignItems: 'flex-start',
  },
  listIndex: {
    width: 28,
    height: 28,
    borderRadius: 14,
    backgroundColor: '#DBEAFE',
    textAlign: 'center',
    lineHeight: 28,
    color: '#1D4ED8',
    fontWeight: '700',
  },
  footerText: {
    textAlign: 'center',
    color: '#64748B',
    paddingVertical: 12,
    fontSize: 12,
  },
  fabricCard: {
    alignSelf: 'center',
    marginVertical: 12,
  },
  noBottomPadding: {
    paddingBottom: 0,
  },
  flexOne: {
    flex: 1,
  },
});
