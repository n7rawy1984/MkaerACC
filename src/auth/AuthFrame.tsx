import type { ReactNode } from 'react';
import { ShieldCheck, ArrowUpRight } from 'lucide-react';
import { useI18n } from '../i18n/I18nContext';
import { NarvoMark } from '../components/ui/NarvoMark';
export function LanguageButton(){const {locale,setLocale}=useI18n();return <button type="button" onClick={()=>setLocale(locale==='en'?'ar':'en')} className="narvo-language">{locale==='en'?'العربية':'English'}</button>;}
export function AuthFrame({children}:{children:ReactNode}){
 const {locale}=useI18n(),ar=locale==='ar';
 return <main className="narvo-auth" dir={ar?'rtl':'ltr'}><aside className="narvo-auth-story"><div className="narvo-auth-brand"><NarvoMark/><strong>NARVO <small>ERP</small></strong></div><div><span className="narvo-auth-eyebrow">{ar?'مساحة واحدة لأعمالك':'ONE WORKSPACE FOR YOUR BUSINESS'}</span><h1>{ar?'وضوح مالي. قرارات بثقة.':'Financial clarity. Business confidence.'}</h1><p>{ar?'المحاسبة والعمليات والتقارير في مساحة عمل مترابطة.':'Accounting, operations and reporting in one connected workspace.'}</p><ArrowUpRight size={38} aria-hidden="true"/></div><p className="narvo-auth-security"><ShieldCheck size={18} aria-hidden="true"/>{ar?'وصول آمن ومخصص لشركتك':'Secure access to your Company workspace'}</p></aside><div className="narvo-auth-content"><header><div className="narvo-auth-mobile-brand"><NarvoMark/><strong>NARVO ERP</strong></div><LanguageButton/></header><section className="narvo-auth-card">{children}</section><footer>NARVO ERP · {ar?'إدارة أعمال متكاملة':'Connected business management'}</footer></div></main>;
}
