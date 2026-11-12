import {createElement} from 'react';
import {Link} from 'react-router-dom';
import type {LucideIcon} from 'lucide-react';
type Item={id:string;label:string;icon:LucideIcon;to?:string};
/** Navigation only. Callers retain the existing view state and authorization. */
export function ModuleNavigation({label,items,active,onSelect}:{label:string;items:Item[];active:string;onSelect?:(id:string)=>void}){
 return <nav className="narvo-module-nav" aria-label={label}>{items.map(item=>item.to?<Link key={item.id} to={item.to} aria-current={active===item.id?'page':undefined}>{createElement(item.icon,{size:17,'aria-hidden':true})}{item.label}</Link>:<button key={item.id} type="button" aria-pressed={active===item.id} onClick={()=>onSelect?.(item.id)}>{createElement(item.icon,{size:17,'aria-hidden':true})}{item.label}</button>)}</nav>;
}
