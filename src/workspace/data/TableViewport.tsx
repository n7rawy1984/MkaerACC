import type{HTMLAttributes}from'react';import'./dataWorkspace.css';
/** A table owns horizontal scrolling only; its page or modal owns vertical scrolling. */
export function TableViewport({label,className='',children,style,...props}:HTMLAttributes<HTMLDivElement>&{label?:string}){return<div {...props} className={'dw-table-viewport '+className} style={{...style,minWidth:0,maxWidth:'100%',maxHeight:'none',overflowX:'auto'}} role="region" aria-label={label??props['aria-label']} tabIndex={0}>{children}</div>;}
