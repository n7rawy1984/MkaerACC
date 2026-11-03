import {useEffect, useId, useRef, useState} from 'react';
import {Check, Palette} from 'lucide-react';
import {useI18n} from '../i18n/I18nContext';

const themes = [
  {id:'emerald', en:'Signature Emerald', ar:'الزمرد المميز', color:'#13856A'},
  {id:'sapphire', en:'Royal Sapphire', ar:'الياقوت الملكي', color:'#315DB4'},
  {id:'graphite', en:'Executive Graphite', ar:'الجرافيت التنفيذي', color:'#485461'},
  {id:'champagne', en:'Warm Champagne', ar:'الشمبانيا الدافئة', color:'#86652D'},
  {id:'teal', en:'Modern Teal', ar:'الفيروزي العصري', color:'#087D89'},
] as const;
type Theme = typeof themes[number]['id'];
const preferenceKey = 'cas:v1:appearance';
function readTheme(): Theme {
  try { const value = localStorage.getItem(preferenceKey); return themes.find(t => t.id === value)?.id ?? 'emerald'; }
  catch { return 'emerald'; }
}
// Appearance only: this module never stores identity, tenant or business data.
export function ThemeSwitcher() {
  const {locale} = useI18n();
  const [theme, setTheme] = useState<Theme>(readTheme);
  const ref = useRef<HTMLDetailsElement>(null);
  const id = useId();
  useEffect(() => { document.documentElement.dataset.theme = theme; }, [theme]);
  useEffect(() => {
    const sync = (event: StorageEvent) => { if (event.key === preferenceKey || event.key === null) setTheme(readTheme()); };
    const close = (event: PointerEvent) => { if (ref.current && !ref.current.contains(event.target as Node)) ref.current.open = false; };
    window.addEventListener('storage', sync); document.addEventListener('pointerdown', close);
    return () => { window.removeEventListener('storage', sync); document.removeEventListener('pointerdown', close); };
  }, []);
  const label = locale === 'ar' ? 'المظهر' : 'Appearance';
  return <details ref={ref} className="theme-selector" onBlur={e => { if (!e.currentTarget.contains(e.relatedTarget as Node)) e.currentTarget.open = false; }} onKeyDown={e => {
    if (e.key === 'Escape') { e.preventDefault(); e.currentTarget.open = false; e.currentTarget.querySelector('summary')?.focus(); }
  }}><summary aria-label={label} aria-controls={id}><Palette size={19} aria-hidden="true"/><span>{label}</span></summary>
    <fieldset id={id} className="theme-options"><legend>{locale === 'ar' ? 'هوية مساحة العمل' : 'Workspace appearance'}</legend>
      {themes.map(item => <label key={item.id} className="theme-option" data-selected={theme === item.id}>
        <input type="radio" name={id} value={item.id} checked={theme === item.id} onChange={() => {
          setTheme(item.id); document.documentElement.dataset.theme = item.id;
          try { localStorage.setItem(preferenceKey, item.id); } catch { /* In-memory selection still works. */ }
        }}/><span className="theme-swatch" style={{background:item.color}} aria-hidden="true"/><span>{item[locale]}</span>{theme === item.id && <Check size={17} aria-hidden="true"/>}
      </label>)}
    </fieldset>
  </details>;
}
