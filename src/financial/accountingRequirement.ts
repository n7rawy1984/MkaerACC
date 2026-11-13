// Deterministic user guidance only; database messages never become posting authority.
export function accountingRequirement(error:unknown,locale:'en'|'ar',action:'post'|'save'='post'){
 const text=error instanceof Error?error.message:String(error),ar=locale==='ar';
 const rules:[RegExp,string,string][]=[
 [/permission|authorization|denied|session|scope/i,'Sign in with the authorized Company accountant.','سجل الدخول بحساب محاسب الشركة المخول.'],
 [/closed|period/i,'Choose a verified date in an open accounting period.','حدد تاريخاً مؤكداً ضمن فترة محاسبية مفتوحة.'],
 [/duplicate|distinct|already|request key|replay/i,'Review the possible duplicate and its existing document.','راجع احتمال تكرار الدفعة ومستندها الموجود.'],
 [/tax|vat|invoice/i,'Complete the applicable VAT treatment and invoice evidence.','استكمل المعالجة الضريبية المطبقة وأدلة الفاتورة.'],
 [/balance|funds|funding/i,'Verify the actual payment account and available balance.','تحقق من حساب الدفع الفعلي ورصيده المتاح.'],
 [/contract|certif/i,'Match the Contract and its approved liability, or use Contractor Advance.','طابق العقد ومستحقه المعتمد، أو استخدم مسار سلفة المقاول.'],
 [/account|mapping|control/i,'Select the appropriate mapped account in Company accounting setup.','حدد الحساب المناسب في إعدادات محاسبة الشركة.'],
 [/date|amount|source/i,'Complete the verified source date, amount and original reference.','استكمل تاريخ المصدر المؤكد ومبلغه ومرجعه الأصلي.'],
 [/changed|version/i,'Refresh the saved version before continuing.','حدّث النسخة المحفوظة قبل المتابعة.']];
 const found=rules.find(([pattern])=>pattern.test(text));const fact=found?(ar?found[2]:found[1]):(ar?'راجع البيانات المطلوبة في النموذج ثم أعد المحاولة بالطلب نفسه.':'Review the required form fields, then retry the same request.');
 return(action==='save'?(ar?'لا يمكن حفظ التعديلات بعد. المطلوب: ':'Cannot save yet. Required: '):(ar?'لا يمكن ترحيل العملية بعد. المطلوب: ':'Cannot post yet. Required: '))+fact;
}
