import type {ReactNode} from 'react';
/** Shared master-record hierarchy. Values remain complete and direction-isolated. */
export function RecordIdentity({code,name,kind,status}:{code?:string|null;name:string;kind?:string;status:ReactNode}) {
  return <header className="record-identity"><div>{code&&<p className="record-code"><bdi dir="ltr">{code}</bdi></p>}<h3><bdi>{name}</bdi></h3>{kind&&<p className="record-kind">{kind}</p>}</div>{status}</header>;
}
