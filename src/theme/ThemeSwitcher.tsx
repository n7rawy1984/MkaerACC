import { Sparkles } from 'lucide-react';
import { useI18n } from '../i18n/I18nContext';
/** Identity indicator, not a nonfunctional appearance menu. Existing appearance preferences remain untouched. */
export function ThemeSwitcher() {
 const {locale}=useI18n();
 return <span className="narvo-identity"><Sparkles size={15} aria-hidden="true"/><span>{locale==='ar'?'نارڤو':'NARVO'}</span></span>;
}
