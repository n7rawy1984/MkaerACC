import type {KeyboardEvent} from 'react';
/** Keep Tab inside a native modal, including single-control detail dialogs. */
export function containDialogTab(event:KeyboardEvent<HTMLElement>){
 if(event.key!=='Tab')return;
 const dialog=event.currentTarget;
 const controls=Array.from(dialog.querySelectorAll<HTMLElement>('button:not(:disabled),a[href],input:not(:disabled):not([type=hidden]),select:not(:disabled),textarea:not(:disabled),[tabindex]:not([tabindex="-1"])')).filter(node=>node.getClientRects().length>0&&!node.closest('[hidden],[inert]'));
 if(!controls.length){event.preventDefault();dialog.focus();return;}
 const first=controls[0],last=controls[controls.length-1],active=document.activeElement;
 if(!dialog.contains(active)||event.shiftKey&&active===first||!event.shiftKey&&active===last){event.preventDefault();(event.shiftKey?last:first).focus();}
}
