import {useId,useLayoutEffect,useRef,useState,type ReactNode} from 'react';
import {createPortal} from 'react-dom';
import './actionPopover.css';
/** Top-layer menus escape transformed/isolated cards and horizontally scrolling tables. */
export function ActionPopover({label,trigger,children,className=''}:{label:string;trigger:ReactNode;children:ReactNode;className?:string}){
 const id=useId(),button=useRef<HTMLButtonElement>(null),panel=useRef<HTMLDivElement>(null),[open,setOpen]=useState(false),[portalRoot,setPortalRoot]=useState<HTMLElement|null>(null);
 const openMenu=()=>{setPortalRoot(button.current?.closest<HTMLDialogElement>('dialog[open]')??document.body);setOpen(true);};
 const close=()=>{panel.current?.hidePopover();setOpen(false);};
 useLayoutEffect(()=>{if(!open)return;const el=panel.current,origin=button.current;if(!el||!origin)return;
  const place=()=>{const r=origin.getBoundingClientRect(),rtl=getComputedStyle(origin).direction==='rtl',width=Math.min(300,innerWidth-24);el.style.width=width+'px';el.style.maxHeight=Math.max(120,innerHeight-24)+'px';const height=el.getBoundingClientRect().height;el.style.left=Math.max(12,Math.min(rtl?r.left:r.right-width,innerWidth-width-12))+'px';el.style.top=Math.max(12,Math.min(r.bottom+8+height<=innerHeight?r.bottom+8:r.top-height-8,innerHeight-height-12))+'px';el.dir=rtl?'rtl':'ltr';};
  el.showPopover();place();el.querySelectorAll<HTMLElement>('a,button').forEach(item=>item.setAttribute('role','menuitem'));el.querySelector<HTMLElement>('a,button:not(:disabled)')?.focus();
  const outside=(event:PointerEvent)=>{if(!el.contains(event.target as Node)&&!origin.contains(event.target as Node))close();};
  window.addEventListener('resize',place);window.addEventListener('scroll',place,true);document.addEventListener('pointerdown',outside);
  return()=>{el.hidePopover();window.removeEventListener('resize',place);window.removeEventListener('scroll',place,true);document.removeEventListener('pointerdown',outside);};
 },[open]);
 return <><button type="button" ref={button} className={'narvo-menu-trigger '+className} aria-label={label} aria-expanded={open} aria-controls={id} aria-haspopup="menu" onClick={()=>open?close():openMenu()} onKeyDown={e=>{if(e.key==='ArrowDown'){e.preventDefault();openMenu();}}}>{trigger}</button>{open&&createPortal(<div ref={panel} id={id} popover="manual" role="menu" aria-label={label} className="narvo-action-popover" onClick={e=>{if((e.target as HTMLElement).closest('a,button'))close();}} onKeyDown={e=>{const items=[...e.currentTarget.querySelectorAll<HTMLElement>('a,button:not(:disabled)')],current=items.indexOf(document.activeElement as HTMLElement);if(e.key==='Escape'){e.preventDefault();e.stopPropagation();close();button.current?.focus();}else if(e.key==='Tab'){close();button.current?.focus();}else if(['ArrowDown','ArrowUp','Home','End'].includes(e.key)){e.preventDefault();items[e.key==='Home'?0:e.key==='End'?items.length-1:(current+(e.key==='ArrowUp'?-1:1)+items.length)%items.length]?.focus();}}}>{children}</div>,portalRoot??document.body)}</>;
}
