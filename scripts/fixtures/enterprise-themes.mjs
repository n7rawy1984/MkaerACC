// Exploration only. Not imported by the product or default build entry.
const shared={
 surface:'#FFFFFF',elevated:'#FFFFFF',inverse:'#FFFFFF',
 successText:'#1A6141',successBg:'#EAF5EE',successBorder:'#49825F',
 warningText:'#75470A',warningBg:'#FFF5E0',warningBorder:'#A16B17',
 dangerText:'#9D2835',dangerBg:'#FFF0F1',dangerBorder:'#B65160',dangerAction:'#AC2939',dangerHover:'#89202E',
 infoText:'#24508A',infoBg:'#EEF4FD',infoBorder:'#587EB4',
 neutralText:'#4E5B6C',neutralBg:'#EFF2F6',neutralBorder:'#7C899B',
 pendingText:'#715222',pendingBg:'#FAF3E5',pendingBorder:'#9A773B',
 disabledText:'#586579',disabledBg:'#E8EDF3',disabledBorder:'#7C899B',
 financialPositive:'#1A6141',financialNegative:'#9D2835',
};
export const themes={
 a:{name:'Executive Blue',letter:'A',direction:'Established financial authority',tokens:{...shared,sidebar:'#111C33',background:'#F6F8FC',primary:'#2454C5',actionText:'#2454C5',primaryHover:'#1B43A0',text:'#17243B',secondary:'#3E506B',muted:'#536078',border:'#DFE5EF',inputBorder:'#75829A',focus:'#2454C5',focusInverse:'#B6CFFF',navText:'#CBD5E8',navMuted:'#A9B8D2',navSelected:'#203E78',navSelectedEdge:'#AAC8FF',tableHeader:'#EDF1F8',tableHover:'#EAF0FD',surfaceSubtle:'#F0F3F9',secondaryBg:'#EEF2FA',secondaryHover:'#DFE8F9'}},
 b:{name:'Emerald Finance',letter:'B',direction:'Restrained and distinctive',tokens:{...shared,sidebar:'#102A27',background:'#F5F8F6',primary:'#087E68',actionText:'#076B59',primaryHover:'#066553',text:'#172C28',secondary:'#36564A',muted:'#4A6258',border:'#DEE9E3',inputBorder:'#70887E',focus:'#087E68',focusInverse:'#A5E1CF',navText:'#C8DED6',navMuted:'#A6C5B9',navSelected:'#185A4B',navSelectedEdge:'#A5E1CF',tableHeader:'#EDF3EF',tableHover:'#E7F3ED',surfaceSubtle:'#EFF4F1',secondaryBg:'#EDF5F0',secondaryHover:'#DCEDE3'}},
 c:{name:'Modern Teal',letter:'C',direction:'Contemporary data clarity',tokens:{...shared,sidebar:'#102B38',background:'#F5F9FA',primary:'#087C91',actionText:'#076A7C',primaryHover:'#086578',text:'#19303A',secondary:'#365765',muted:'#49616D',border:'#DFE8ED',inputBorder:'#71858F',focus:'#087C91',focusInverse:'#AADEEB',navText:'#C8DEE7',navMuted:'#A7C3CF',navSelected:'#18566A',navSelectedEdge:'#AADEEB',tableHeader:'#EDF3F6',tableHover:'#E7F3F6',surfaceSubtle:'#EFF5F7',secondaryBg:'#EBF4F7',secondaryHover:'#DCECF1'}},
};
export const variableName=k=>'--n-'+k.replace(/[A-Z]/g,c=>'-'+c.toLowerCase());
export const themeDeclarations=Object.entries(themes).map(([key,t])=>`html[data-narvo-theme="${key}"]{${Object.entries(t.tokens).map(([k,v])=>`${variableName(k)}:${v}`).join(';')}}`).join('\n');
export const references=[
 {title:'IBM Carbon — Color roles, layers and tokens',url:'https://www.carbondesignsystem.com/building-blocks/foundations/color/overview'},
 {title:'Atlassian — Semantic color tokens and roles',url:'https://atlassian.design/foundations/color/'},
 {title:'W3C — WCAG2.2 Contrast Minimum',url:'https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html'},
 {title:'W3C — WCAG2.2 Non-text Contrast',url:'https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html'},
 {title:'W3C — Focus Visible',url:'https://www.w3.org/WAI/WCAG22/Understanding/focus-visible.html'},
];
