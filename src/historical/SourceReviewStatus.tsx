import {sourceLinked,type SourceRecord} from './sourceModel';
import {sourceNeedsReview,sourceUnpostedWarning,sourceReviewIssues,sourceReviewIssueLabel,sourceSavedReviewReasons} from './sourceReviewPresentation';
export function SourceReviewStatus({row,locale,expanded=false}:{row:SourceRecord;locale:'en'|'ar';expanded?:boolean}){
 if(!sourceNeedsReview(row))return null;
 const saved=sourceSavedReviewReasons(row,locale);
 return <div className="mt-2 rounded border border-amber-300 bg-amber-50 p-2 text-sm text-amber-950" aria-label={sourceUnpostedWarning(locale)}>
  <p className="font-medium">{locale==='ar'?'لا يمكن ترحيل العملية بعد. المطلوب: ':'Cannot post yet. Required: '}{sourceReviewIssues(row).length?sourceReviewIssueLabel(sourceReviewIssues(row)[0],locale):saved[0]}</p>
  <details open={expanded}><summary className="cursor-pointer">{locale==='ar'?'المعلومات المطلوبة قبل الترحيل':'Information required before posting'}</summary>
   <ul className="mt-2 list-inside list-disc">{sourceReviewIssues(row).map(code=><li key={code}>{sourceReviewIssueLabel(code,locale)}</li>)}</ul>
   {saved.length>0&&<><p className="mt-2 font-medium">{locale==='ar'?'متطلبات المراجعة المحفوظة':'Saved review requirements'}</p><ul className="list-inside list-disc">{saved.map((reason,i)=><li key={i}>{reason}</li>)}</ul></>}
   {!sourceLinked(row)&&<p className="mt-2">{locale==='ar'?'استكمل البيانات في تعديل المصدر والمسودة المحاسبية المرتبطة. حفظ البيانات لا يرحّل قيداً؛ يعيد الأمر المحاسبي التحقق قبل الترحيل.':'Complete the source details and linked canonical draft. Saving creates no journal; the canonical command revalidates before posting.'}</p>}
  </details>
 </div>;
}
