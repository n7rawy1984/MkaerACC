export type PayrollCommandName='prepare_payroll_accounting'|'post_payroll'|'pay_salary'|'reverse_salary_payment'|'reverse_payroll';
export interface PayrollCommand {name:PayrollCommandName;args:Record<string,unknown>}
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export const payrollAttemptKey=(user:string,company:string)=>`makeracc:payroll-command:${user}:${company}`;
export function loadPayrollAttempt(storage:Storage,user:string,company:string):PayrollCommand|null {
 const raw=storage.getItem(payrollAttemptKey(user,company));if(!raw)return null;
 const p=JSON.parse(raw);if(p.user!==user||p.company!==company||p.version!==1||!['post_payroll','pay_salary','reverse_salary_payment','reverse_payroll'].includes(p.command?.name)||p.command?.args?.target_company_id!==company||!uuid.test(p.command?.args?.target_idempotency_key))throw Error('Invalid saved payroll request');
 if(p.command.name==='pay_salary'&&(typeof p.command.args.target_amount_minor!=='string'||!/^\d+$/.test(p.command.args.target_amount_minor)))throw Error('Invalid saved exact payment');
 return p.command;
}
export function savePayrollAttempt(storage:Storage,user:string,company:string,command:PayrollCommand){
 if(command.name!=='prepare_payroll_accounting')storage.setItem(payrollAttemptKey(user,company),JSON.stringify({version:1,user,company,command}));
}
export function clearPayrollAttempt(storage:Storage,user:string,company:string){storage.removeItem(payrollAttemptKey(user,company));}
