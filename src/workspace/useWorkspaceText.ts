import {useI18n} from '../i18n/I18nContext';
import {workspaceText,type WorkspaceTextKey} from './workspaceText';
export function useWorkspaceText(){const {locale}=useI18n();return(key:WorkspaceTextKey)=>workspaceText[locale][key];}
