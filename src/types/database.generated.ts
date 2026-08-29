export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.5"
  }
  graphql_public: {
    Tables: {
      [_ in never]: never
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      graphql: {
        Args: {
          extensions?: Json
          operationName?: string
          query?: string
          variables?: Json
        }
        Returns: Json
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
  public: {
    Tables: {
      accounts: {
        Row: {
          account_type: Database["public"]["Enums"]["account_type"]
          code: string
          company_id: string
          created_at: string
          created_by: string | null
          id: string
          name: string
          parent_account_id: string | null
          requires_party: boolean
          status: Database["public"]["Enums"]["account_status"]
          system_key: Database["public"]["Enums"]["system_account_key"] | null
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          account_type: Database["public"]["Enums"]["account_type"]
          code: string
          company_id: string
          created_at?: string
          created_by?: string | null
          id?: string
          name: string
          parent_account_id?: string | null
          requires_party?: boolean
          status?: Database["public"]["Enums"]["account_status"]
          system_key?: Database["public"]["Enums"]["system_account_key"] | null
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          account_type?: Database["public"]["Enums"]["account_type"]
          code?: string
          company_id?: string
          created_at?: string
          created_by?: string | null
          id?: string
          name?: string
          parent_account_id?: string | null
          requires_party?: boolean
          status?: Database["public"]["Enums"]["account_status"]
          system_key?: Database["public"]["Enums"]["system_account_key"] | null
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "accounts_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "accounts_parent_same_company"
            columns: ["company_id", "parent_account_id"]
            isOneToOne: false
            referencedRelation: "accounts"
            referencedColumns: ["company_id", "id"]
          },
        ]
      }
      companies: {
        Row: {
          address: string | null
          code: string
          created_at: string
          created_by: string | null
          id: string
          legal_name: string | null
          name: string
          notes: string | null
          status: Database["public"]["Enums"]["account_status"]
          trn: string | null
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          address?: string | null
          code: string
          created_at?: string
          created_by?: string | null
          id?: string
          legal_name?: string | null
          name: string
          notes?: string | null
          status?: Database["public"]["Enums"]["account_status"]
          trn?: string | null
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          address?: string | null
          code?: string
          created_at?: string
          created_by?: string | null
          id?: string
          legal_name?: string | null
          name?: string
          notes?: string | null
          status?: Database["public"]["Enums"]["account_status"]
          trn?: string | null
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: []
      }
      company_memberships: {
        Row: {
          company_id: string
          created_at: string
          created_by: string | null
          id: string
          role: Database["public"]["Enums"]["company_role"]
          status: Database["public"]["Enums"]["account_status"]
          updated_at: string
          updated_by: string | null
          user_id: string
        }
        Insert: {
          company_id: string
          created_at?: string
          created_by?: string | null
          id?: string
          role: Database["public"]["Enums"]["company_role"]
          status?: Database["public"]["Enums"]["account_status"]
          updated_at?: string
          updated_by?: string | null
          user_id: string
        }
        Update: {
          company_id?: string
          created_at?: string
          created_by?: string | null
          id?: string
          role?: Database["public"]["Enums"]["company_role"]
          status?: Database["public"]["Enums"]["account_status"]
          updated_at?: string
          updated_by?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "company_memberships_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      custody_advances: {
        Row: {
          advance_date: string
          advance_reference: string
          amount_minor: number
          company_id: string
          created_at: string
          created_by: string | null
          custodian_id: string
          external_reference: string | null
          id: string
          notes: string | null
          payment_method: Database["public"]["Enums"]["payment_method"]
          posted_at: string | null
          posted_by: string | null
          posted_journal_entry_id: string | null
          project_id: string | null
          reversal_journal_entry_id: string | null
          reversed_at: string | null
          reversed_by: string | null
          status: Database["public"]["Enums"]["expense_status"]
          treasury_account_id: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          advance_date: string
          advance_reference: string
          amount_minor: number
          company_id: string
          created_at?: string
          created_by?: string | null
          custodian_id: string
          external_reference?: string | null
          id?: string
          notes?: string | null
          payment_method: Database["public"]["Enums"]["payment_method"]
          posted_at?: string | null
          posted_by?: string | null
          posted_journal_entry_id?: string | null
          project_id?: string | null
          reversal_journal_entry_id?: string | null
          reversed_at?: string | null
          reversed_by?: string | null
          status?: Database["public"]["Enums"]["expense_status"]
          treasury_account_id: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          advance_date?: string
          advance_reference?: string
          amount_minor?: number
          company_id?: string
          created_at?: string
          created_by?: string | null
          custodian_id?: string
          external_reference?: string | null
          id?: string
          notes?: string | null
          payment_method?: Database["public"]["Enums"]["payment_method"]
          posted_at?: string | null
          posted_by?: string | null
          posted_journal_entry_id?: string | null
          project_id?: string | null
          reversal_journal_entry_id?: string | null
          reversed_at?: string | null
          reversed_by?: string | null
          status?: Database["public"]["Enums"]["expense_status"]
          treasury_account_id?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "custody_advances_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "custody_advances_custodian_same_company"
            columns: ["company_id", "custodian_id"]
            isOneToOne: false
            referencedRelation: "parties"
            referencedColumns: ["company_id", "id"]
          },
          {
            foreignKeyName: "custody_advances_posted_journal_same_company"
            columns: ["company_id", "posted_journal_entry_id"]
            isOneToOne: false
            referencedRelation: "journal_entries"
            referencedColumns: ["company_id", "id"]
          },
          {
            foreignKeyName: "custody_advances_project_same_company"
            columns: ["company_id", "project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["company_id", "id"]
          },
          {
            foreignKeyName: "custody_advances_reversal_journal_same_company"
            columns: ["company_id", "reversal_journal_entry_id"]
            isOneToOne: false
            referencedRelation: "journal_entries"
            referencedColumns: ["company_id", "id"]
          },
          {
            foreignKeyName: "custody_advances_treasury_same_company"
            columns: ["company_id", "treasury_account_id"]
            isOneToOne: false
            referencedRelation: "treasury_accounts"
            referencedColumns: ["company_id", "id"]
          },
        ]
      }
      custody_cash_returns: {
        Row: {
          amount_minor: number
          company_id: string
          created_at: string
          created_by: string
          custodian_id: string
          external_reference: string | null
          id: string
          notes: string | null
          payment_method: Database["public"]["Enums"]["payment_method"]
          posted_at: string | null
          posted_by: string | null
          posted_journal_entry_id: string | null
          return_date: string
          return_reference: string
          reversal_journal_entry_id: string | null
          reversed_at: string | null
          reversed_by: string | null
          status: Database["public"]["Enums"]["expense_status"]
          treasury_account_id: string
          updated_at: string
          updated_by: string
        }
        Insert: {
          amount_minor: number
          company_id: string
          created_at?: string
          created_by: string
          custodian_id: string
          external_reference?: string | null
          id?: string
          notes?: string | null
          payment_method: Database["public"]["Enums"]["payment_method"]
          posted_at?: string | null
          posted_by?: string | null
          posted_journal_entry_id?: string | null
          return_date: string
          return_reference: string
          reversal_journal_entry_id?: string | null
          reversed_at?: string | null
          reversed_by?: string | null
          status?: Database["public"]["Enums"]["expense_status"]
          treasury_account_id: string
          updated_at?: string
          updated_by: string
        }
        Update: {
          amount_minor?: number
          company_id?: string
          created_at?: string
          created_by?: string
          custodian_id?: string
          external_reference?: string | null
          id?: string
          notes?: string | null
          payment_method?: Database["public"]["Enums"]["payment_method"]
          posted_at?: string | null
          posted_by?: string | null
          posted_journal_entry_id?: string | null
          return_date?: string
          return_reference?: string
          reversal_journal_entry_id?: string | null
          reversed_at?: string | null
          reversed_by?: string | null
          status?: Database["public"]["Enums"]["expense_status"]
          treasury_account_id?: string
          updated_at?: string
          updated_by?: string
        }
        Relationships: [
          {
            foreignKeyName: "custody_cash_returns_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "custody_cash_returns_custodian_same_company"
            columns: ["company_id", "custodian_id"]
            isOneToOne: false
            referencedRelation: "parties"
            referencedColumns: ["company_id", "id"]
          },
          {
            foreignKeyName: "custody_cash_returns_posted_journal_same_company"
            columns: ["company_id", "posted_journal_entry_id"]
            isOneToOne: false
            referencedRelation: "journal_entries"
            referencedColumns: ["company_id", "id"]
          },
          {
            foreignKeyName: "custody_cash_returns_reversal_journal_same_company"
            columns: ["company_id", "reversal_journal_entry_id"]
            isOneToOne: false
            referencedRelation: "journal_entries"
            referencedColumns: ["company_id", "id"]
          },
          {
            foreignKeyName: "custody_cash_returns_treasury_same_company"
            columns: ["company_id", "treasury_account_id"]
            isOneToOne: false
            referencedRelation: "treasury_accounts"
            referencedColumns: ["company_id", "id"]
          },
        ]
      }
      custody_settlement_items: {
        Row: {
          company_id: string
          created_at: string
          expense_amount_minor: number
          expense_id: string
          id: string
          settlement_id: string
        }
        Insert: {
          company_id: string
          created_at?: string
          expense_amount_minor: number
          expense_id: string
          id?: string
          settlement_id: string
        }
        Update: {
          company_id?: string
          created_at?: string
          expense_amount_minor?: number
          expense_id?: string
          id?: string
          settlement_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "custody_settlement_items_expense_same_company"
            columns: ["company_id", "expense_id"]
            isOneToOne: false
            referencedRelation: "expenses"
            referencedColumns: ["company_id", "id"]
          },
          {
            foreignKeyName: "custody_settlement_items_settlement_same_company"
            columns: ["company_id", "settlement_id"]
            isOneToOne: false
            referencedRelation: "custody_settlements"
            referencedColumns: ["company_id", "id"]
          },
        ]
      }
      custody_settlements: {
        Row: {
          company_id: string
          created_at: string
          created_by: string
          custodian_id: string
          finalized_at: string | null
          finalized_by: string | null
          id: string
          notes: string | null
          settlement_date: string
          settlement_reference: string
          status: Database["public"]["Enums"]["custody_settlement_status"]
          total_expenses_minor: number
        }
        Insert: {
          company_id: string
          created_at?: string
          created_by: string
          custodian_id: string
          finalized_at?: string | null
          finalized_by?: string | null
          id?: string
          notes?: string | null
          settlement_date: string
          settlement_reference: string
          status?: Database["public"]["Enums"]["custody_settlement_status"]
          total_expenses_minor: number
        }
        Update: {
          company_id?: string
          created_at?: string
          created_by?: string
          custodian_id?: string
          finalized_at?: string | null
          finalized_by?: string | null
          id?: string
          notes?: string | null
          settlement_date?: string
          settlement_reference?: string
          status?: Database["public"]["Enums"]["custody_settlement_status"]
          total_expenses_minor?: number
        }
        Relationships: [
          {
            foreignKeyName: "custody_settlements_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "custody_settlements_custodian_same_company"
            columns: ["company_id", "custodian_id"]
            isOneToOne: false
            referencedRelation: "parties"
            referencedColumns: ["company_id", "id"]
          },
        ]
      }
      expense_categories: {
        Row: {
          code: string
          company_id: string
          created_at: string
          created_by: string | null
          description: string | null
          id: string
          name: string
          status: Database["public"]["Enums"]["account_status"]
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          code: string
          company_id: string
          created_at?: string
          created_by?: string | null
          description?: string | null
          id?: string
          name: string
          status?: Database["public"]["Enums"]["account_status"]
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          code?: string
          company_id?: string
          created_at?: string
          created_by?: string | null
          description?: string | null
          id?: string
          name?: string
          status?: Database["public"]["Enums"]["account_status"]
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "expense_categories_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      expenses: {
        Row: {
          company_id: string
          created_at: string
          created_by: string | null
          description: string
          expense_category_id: string
          expense_date: string
          expense_reference: string
          funding_mode: Database["public"]["Enums"]["expense_funding_mode"]
          gross_amount_minor: number
          has_tax_invoice: boolean
          id: string
          invoice_number: string | null
          net_amount_minor: number
          notes: string | null
          paid_by_party_id: string | null
          payment_method: Database["public"]["Enums"]["payment_method"]
          posted_at: string | null
          posted_by: string | null
          posted_journal_entry_id: string | null
          project_id: string | null
          reversal_journal_entry_id: string | null
          reversed_at: string | null
          reversed_by: string | null
          status: Database["public"]["Enums"]["expense_status"]
          supplier_id: string | null
          treasury_account_id: string | null
          updated_at: string
          updated_by: string | null
          vat_amount_minor: number
          vat_mode: Database["public"]["Enums"]["expense_vat_mode"]
        }
        Insert: {
          company_id: string
          created_at?: string
          created_by?: string | null
          description: string
          expense_category_id: string
          expense_date: string
          expense_reference: string
          funding_mode: Database["public"]["Enums"]["expense_funding_mode"]
          gross_amount_minor: number
          has_tax_invoice?: boolean
          id?: string
          invoice_number?: string | null
          net_amount_minor: number
          notes?: string | null
          paid_by_party_id?: string | null
          payment_method: Database["public"]["Enums"]["payment_method"]
          posted_at?: string | null
          posted_by?: string | null
          posted_journal_entry_id?: string | null
          project_id?: string | null
          reversal_journal_entry_id?: string | null
          reversed_at?: string | null
          reversed_by?: string | null
          status?: Database["public"]["Enums"]["expense_status"]
          supplier_id?: string | null
          treasury_account_id?: string | null
          updated_at?: string
          updated_by?: string | null
          vat_amount_minor: number
          vat_mode: Database["public"]["Enums"]["expense_vat_mode"]
        }
        Update: {
          company_id?: string
          created_at?: string
          created_by?: string | null
          description?: string
          expense_category_id?: string
          expense_date?: string
          expense_reference?: string
          funding_mode?: Database["public"]["Enums"]["expense_funding_mode"]
          gross_amount_minor?: number
          has_tax_invoice?: boolean
          id?: string
          invoice_number?: string | null
          net_amount_minor?: number
          notes?: string | null
          paid_by_party_id?: string | null
          payment_method?: Database["public"]["Enums"]["payment_method"]
          posted_at?: string | null
          posted_by?: string | null
          posted_journal_entry_id?: string | null
          project_id?: string | null
          reversal_journal_entry_id?: string | null
          reversed_at?: string | null
          reversed_by?: string | null
          status?: Database["public"]["Enums"]["expense_status"]
          supplier_id?: string | null
          treasury_account_id?: string | null
          updated_at?: string
          updated_by?: string | null
          vat_amount_minor?: number
          vat_mode?: Database["public"]["Enums"]["expense_vat_mode"]
        }
        Relationships: [
          {
            foreignKeyName: "expenses_category_same_company"
            columns: ["company_id", "expense_category_id"]
            isOneToOne: false
            referencedRelation: "expense_categories"
            referencedColumns: ["company_id", "id"]
          },
          {
            foreignKeyName: "expenses_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "expenses_paid_by_party_same_company"
            columns: ["company_id", "paid_by_party_id"]
            isOneToOne: false
            referencedRelation: "parties"
            referencedColumns: ["company_id", "id"]
          },
          {
            foreignKeyName: "expenses_posted_journal_same_company"
            columns: ["company_id", "posted_journal_entry_id"]
            isOneToOne: false
            referencedRelation: "journal_entries"
            referencedColumns: ["company_id", "id"]
          },
          {
            foreignKeyName: "expenses_project_same_company"
            columns: ["company_id", "project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["company_id", "id"]
          },
          {
            foreignKeyName: "expenses_reversal_journal_same_company"
            columns: ["company_id", "reversal_journal_entry_id"]
            isOneToOne: false
            referencedRelation: "journal_entries"
            referencedColumns: ["company_id", "id"]
          },
          {
            foreignKeyName: "expenses_supplier_same_company"
            columns: ["company_id", "supplier_id"]
            isOneToOne: false
            referencedRelation: "parties"
            referencedColumns: ["company_id", "id"]
          },
          {
            foreignKeyName: "expenses_treasury_same_company"
            columns: ["company_id", "treasury_account_id"]
            isOneToOne: false
            referencedRelation: "treasury_accounts"
            referencedColumns: ["company_id", "id"]
          },
        ]
      }
      journal_entries: {
        Row: {
          company_id: string
          created_at: string
          created_by: string | null
          description: string
          id: string
          journal_reference: string
          posted_at: string
          posting_date: string
          posting_purpose: string
          reversal_of_journal_entry_id: string | null
          source_id: string
          source_type: string
        }
        Insert: {
          company_id: string
          created_at?: string
          created_by?: string | null
          description: string
          id?: string
          journal_reference: string
          posted_at?: string
          posting_date: string
          posting_purpose: string
          reversal_of_journal_entry_id?: string | null
          source_id: string
          source_type: string
        }
        Update: {
          company_id?: string
          created_at?: string
          created_by?: string | null
          description?: string
          id?: string
          journal_reference?: string
          posted_at?: string
          posting_date?: string
          posting_purpose?: string
          reversal_of_journal_entry_id?: string | null
          source_id?: string
          source_type?: string
        }
        Relationships: [
          {
            foreignKeyName: "journal_entries_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "journal_entries_reversal_same_company"
            columns: ["company_id", "reversal_of_journal_entry_id"]
            isOneToOne: false
            referencedRelation: "journal_entries"
            referencedColumns: ["company_id", "id"]
          },
        ]
      }
      journal_lines: {
        Row: {
          account_id: string
          company_id: string
          created_at: string
          credit_minor: number
          debit_minor: number
          id: string
          journal_entry_id: string
          line_number: number
          memo: string | null
          party_id: string | null
          project_id: string | null
          subcontract_id: string | null
          treasury_account_id: string | null
        }
        Insert: {
          account_id: string
          company_id: string
          created_at?: string
          credit_minor?: number
          debit_minor?: number
          id?: string
          journal_entry_id: string
          line_number: number
          memo?: string | null
          party_id?: string | null
          project_id?: string | null
          subcontract_id?: string | null
          treasury_account_id?: string | null
        }
        Update: {
          account_id?: string
          company_id?: string
          created_at?: string
          credit_minor?: number
          debit_minor?: number
          id?: string
          journal_entry_id?: string
          line_number?: number
          memo?: string | null
          party_id?: string | null
          project_id?: string | null
          subcontract_id?: string | null
          treasury_account_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "journal_lines_account_same_company"
            columns: ["company_id", "account_id"]
            isOneToOne: false
            referencedRelation: "accounts"
            referencedColumns: ["company_id", "id"]
          },
          {
            foreignKeyName: "journal_lines_entry_same_company"
            columns: ["company_id", "journal_entry_id"]
            isOneToOne: false
            referencedRelation: "journal_entries"
            referencedColumns: ["company_id", "id"]
          },
          {
            foreignKeyName: "journal_lines_party_same_company"
            columns: ["company_id", "party_id"]
            isOneToOne: false
            referencedRelation: "parties"
            referencedColumns: ["company_id", "id"]
          },
          {
            foreignKeyName: "journal_lines_project_same_company"
            columns: ["company_id", "project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["company_id", "id"]
          },
          {
            foreignKeyName: "journal_lines_subcontract_project_same_company"
            columns: ["company_id", "subcontract_id", "project_id"]
            isOneToOne: false
            referencedRelation: "subcontracts"
            referencedColumns: ["company_id", "id", "project_id"]
          },
          {
            foreignKeyName: "journal_lines_treasury_same_company"
            columns: ["company_id", "treasury_account_id"]
            isOneToOne: false
            referencedRelation: "treasury_accounts"
            referencedColumns: ["company_id", "id"]
          },
        ]
      }
      parties: {
        Row: {
          address: string | null
          code: string | null
          company_id: string
          contact_person: string | null
          created_at: string
          created_by: string | null
          email: string | null
          id: string
          name: string
          notes: string | null
          phone: string | null
          status: Database["public"]["Enums"]["account_status"]
          trn: string | null
          type: Database["public"]["Enums"]["party_type"]
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          address?: string | null
          code?: string | null
          company_id: string
          contact_person?: string | null
          created_at?: string
          created_by?: string | null
          email?: string | null
          id?: string
          name: string
          notes?: string | null
          phone?: string | null
          status?: Database["public"]["Enums"]["account_status"]
          trn?: string | null
          type: Database["public"]["Enums"]["party_type"]
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          address?: string | null
          code?: string | null
          company_id?: string
          contact_person?: string | null
          created_at?: string
          created_by?: string | null
          email?: string | null
          id?: string
          name?: string
          notes?: string | null
          phone?: string | null
          status?: Database["public"]["Enums"]["account_status"]
          trn?: string | null
          type?: Database["public"]["Enums"]["party_type"]
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "parties_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      permissions: {
        Row: {
          description: string
          key: string
        }
        Insert: {
          description: string
          key: string
        }
        Update: {
          description?: string
          key?: string
        }
        Relationships: []
      }
      profiles: {
        Row: {
          created_at: string
          display_name: string
          email_snapshot: string | null
          locale: Database["public"]["Enums"]["app_locale"]
          status: Database["public"]["Enums"]["account_status"]
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          display_name: string
          email_snapshot?: string | null
          locale?: Database["public"]["Enums"]["app_locale"]
          status?: Database["public"]["Enums"]["account_status"]
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          display_name?: string
          email_snapshot?: string | null
          locale?: Database["public"]["Enums"]["app_locale"]
          status?: Database["public"]["Enums"]["account_status"]
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      project_assignments: {
        Row: {
          company_id: string
          created_at: string
          created_by: string | null
          id: string
          project_id: string
          status: Database["public"]["Enums"]["account_status"]
          updated_at: string
          updated_by: string | null
          user_id: string
        }
        Insert: {
          company_id: string
          created_at?: string
          created_by?: string | null
          id?: string
          project_id: string
          status?: Database["public"]["Enums"]["account_status"]
          updated_at?: string
          updated_by?: string | null
          user_id: string
        }
        Update: {
          company_id?: string
          created_at?: string
          created_by?: string | null
          id?: string
          project_id?: string
          status?: Database["public"]["Enums"]["account_status"]
          updated_at?: string
          updated_by?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "project_assignments_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "project_assignments_project_same_company"
            columns: ["company_id", "project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["company_id", "id"]
          },
        ]
      }
      projects: {
        Row: {
          budget_minor: number | null
          client_name: string | null
          code: string
          company_id: string
          contract_number: string | null
          created_at: string
          created_by: string | null
          expected_completion_date: string | null
          id: string
          location: string | null
          name: string
          notes: string | null
          original_contract_value_minor: number | null
          start_date: string | null
          status: Database["public"]["Enums"]["project_status"]
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          budget_minor?: number | null
          client_name?: string | null
          code: string
          company_id: string
          contract_number?: string | null
          created_at?: string
          created_by?: string | null
          expected_completion_date?: string | null
          id?: string
          location?: string | null
          name: string
          notes?: string | null
          original_contract_value_minor?: number | null
          start_date?: string | null
          status?: Database["public"]["Enums"]["project_status"]
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          budget_minor?: number | null
          client_name?: string | null
          code?: string
          company_id?: string
          contract_number?: string | null
          created_at?: string
          created_by?: string | null
          expected_completion_date?: string | null
          id?: string
          location?: string | null
          name?: string
          notes?: string | null
          original_contract_value_minor?: number | null
          start_date?: string | null
          status?: Database["public"]["Enums"]["project_status"]
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "projects_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      role_permissions: {
        Row: {
          permission_key: string
          role: Database["public"]["Enums"]["company_role"]
        }
        Insert: {
          permission_key: string
          role: Database["public"]["Enums"]["company_role"]
        }
        Update: {
          permission_key?: string
          role?: Database["public"]["Enums"]["company_role"]
        }
        Relationships: [
          {
            foreignKeyName: "role_permissions_permission_key_fkey"
            columns: ["permission_key"]
            isOneToOne: false
            referencedRelation: "permissions"
            referencedColumns: ["key"]
          },
        ]
      }
      subcontractor_advances: {
        Row: {
          advance_date: string
          advance_reference: string
          amount_minor: number
          company_id: string
          created_at: string
          created_by: string
          external_reference: string | null
          id: string
          notes: string | null
          payment_method: Database["public"]["Enums"]["payment_method"]
          posted_at: string | null
          posted_by: string | null
          posted_journal_entry_id: string | null
          project_id: string
          reversal_journal_entry_id: string | null
          reversed_at: string | null
          reversed_by: string | null
          status: Database["public"]["Enums"]["expense_status"]
          subcontract_id: string
          subcontractor_id: string
          treasury_account_id: string
          updated_at: string
          updated_by: string
        }
        Insert: {
          advance_date: string
          advance_reference: string
          amount_minor: number
          company_id: string
          created_at?: string
          created_by: string
          external_reference?: string | null
          id?: string
          notes?: string | null
          payment_method: Database["public"]["Enums"]["payment_method"]
          posted_at?: string | null
          posted_by?: string | null
          posted_journal_entry_id?: string | null
          project_id: string
          reversal_journal_entry_id?: string | null
          reversed_at?: string | null
          reversed_by?: string | null
          status?: Database["public"]["Enums"]["expense_status"]
          subcontract_id: string
          subcontractor_id: string
          treasury_account_id: string
          updated_at?: string
          updated_by: string
        }
        Update: {
          advance_date?: string
          advance_reference?: string
          amount_minor?: number
          company_id?: string
          created_at?: string
          created_by?: string
          external_reference?: string | null
          id?: string
          notes?: string | null
          payment_method?: Database["public"]["Enums"]["payment_method"]
          posted_at?: string | null
          posted_by?: string | null
          posted_journal_entry_id?: string | null
          project_id?: string
          reversal_journal_entry_id?: string | null
          reversed_at?: string | null
          reversed_by?: string | null
          status?: Database["public"]["Enums"]["expense_status"]
          subcontract_id?: string
          subcontractor_id?: string
          treasury_account_id?: string
          updated_at?: string
          updated_by?: string
        }
        Relationships: [
          {
            foreignKeyName: "subcontractor_advances_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "subcontractor_advances_party_same_company"
            columns: ["company_id", "subcontractor_id"]
            isOneToOne: false
            referencedRelation: "parties"
            referencedColumns: ["company_id", "id"]
          },
          {
            foreignKeyName: "subcontractor_advances_posted_journal_same_company"
            columns: ["company_id", "posted_journal_entry_id"]
            isOneToOne: false
            referencedRelation: "journal_entries"
            referencedColumns: ["company_id", "id"]
          },
          {
            foreignKeyName: "subcontractor_advances_project_same_company"
            columns: ["company_id", "project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["company_id", "id"]
          },
          {
            foreignKeyName: "subcontractor_advances_reversal_journal_same_company"
            columns: ["company_id", "reversal_journal_entry_id"]
            isOneToOne: false
            referencedRelation: "journal_entries"
            referencedColumns: ["company_id", "id"]
          },
          {
            foreignKeyName: "subcontractor_advances_subcontract_identity"
            columns: [
              "company_id",
              "subcontract_id",
              "project_id",
              "subcontractor_id",
            ]
            isOneToOne: false
            referencedRelation: "subcontracts"
            referencedColumns: [
              "company_id",
              "id",
              "project_id",
              "subcontractor_id",
            ]
          },
          {
            foreignKeyName: "subcontractor_advances_treasury_same_company"
            columns: ["company_id", "treasury_account_id"]
            isOneToOne: false
            referencedRelation: "treasury_accounts"
            referencedColumns: ["company_id", "id"]
          },
        ]
      }
      subcontracts: {
        Row: {
          approved_variations_minor: number
          company_id: string
          contract_number: string
          created_at: string
          created_by: string | null
          expected_end_date: string | null
          id: string
          notes: string | null
          original_contract_value_minor: number
          project_id: string
          retention_bps: number
          scope_of_work: string
          start_date: string | null
          status: Database["public"]["Enums"]["subcontract_status"]
          subcontractor_id: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          approved_variations_minor?: number
          company_id: string
          contract_number: string
          created_at?: string
          created_by?: string | null
          expected_end_date?: string | null
          id?: string
          notes?: string | null
          original_contract_value_minor: number
          project_id: string
          retention_bps: number
          scope_of_work: string
          start_date?: string | null
          status?: Database["public"]["Enums"]["subcontract_status"]
          subcontractor_id: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          approved_variations_minor?: number
          company_id?: string
          contract_number?: string
          created_at?: string
          created_by?: string | null
          expected_end_date?: string | null
          id?: string
          notes?: string | null
          original_contract_value_minor?: number
          project_id?: string
          retention_bps?: number
          scope_of_work?: string
          start_date?: string | null
          status?: Database["public"]["Enums"]["subcontract_status"]
          subcontractor_id?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "subcontracts_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "subcontracts_party_same_company"
            columns: ["company_id", "subcontractor_id"]
            isOneToOne: false
            referencedRelation: "parties"
            referencedColumns: ["company_id", "id"]
          },
          {
            foreignKeyName: "subcontracts_project_same_company"
            columns: ["company_id", "project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["company_id", "id"]
          },
        ]
      }
      supplier_payment_allocations: {
        Row: {
          allocated_amount_minor: number
          company_id: string
          created_at: string
          created_by: string | null
          expense_id: string
          id: string
          supplier_payment_id: string
        }
        Insert: {
          allocated_amount_minor: number
          company_id: string
          created_at?: string
          created_by?: string | null
          expense_id: string
          id?: string
          supplier_payment_id: string
        }
        Update: {
          allocated_amount_minor?: number
          company_id?: string
          created_at?: string
          created_by?: string | null
          expense_id?: string
          id?: string
          supplier_payment_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "supplier_payment_allocations_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "supplier_payment_allocations_expense_same_company"
            columns: ["company_id", "expense_id"]
            isOneToOne: false
            referencedRelation: "expenses"
            referencedColumns: ["company_id", "id"]
          },
          {
            foreignKeyName: "supplier_payment_allocations_payment_same_company"
            columns: ["company_id", "supplier_payment_id"]
            isOneToOne: false
            referencedRelation: "supplier_payments"
            referencedColumns: ["company_id", "id"]
          },
        ]
      }
      supplier_payments: {
        Row: {
          company_id: string
          created_at: string
          created_by: string | null
          external_reference: string | null
          id: string
          notes: string | null
          payment_date: string
          payment_method: Database["public"]["Enums"]["payment_method"]
          payment_reference: string
          posted_at: string | null
          posted_by: string | null
          posted_journal_entry_id: string | null
          reversal_journal_entry_id: string | null
          reversed_at: string | null
          reversed_by: string | null
          status: Database["public"]["Enums"]["expense_status"]
          supplier_id: string
          total_amount_minor: number
          treasury_account_id: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          company_id: string
          created_at?: string
          created_by?: string | null
          external_reference?: string | null
          id?: string
          notes?: string | null
          payment_date: string
          payment_method: Database["public"]["Enums"]["payment_method"]
          payment_reference: string
          posted_at?: string | null
          posted_by?: string | null
          posted_journal_entry_id?: string | null
          reversal_journal_entry_id?: string | null
          reversed_at?: string | null
          reversed_by?: string | null
          status?: Database["public"]["Enums"]["expense_status"]
          supplier_id: string
          total_amount_minor: number
          treasury_account_id: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          company_id?: string
          created_at?: string
          created_by?: string | null
          external_reference?: string | null
          id?: string
          notes?: string | null
          payment_date?: string
          payment_method?: Database["public"]["Enums"]["payment_method"]
          payment_reference?: string
          posted_at?: string | null
          posted_by?: string | null
          posted_journal_entry_id?: string | null
          reversal_journal_entry_id?: string | null
          reversed_at?: string | null
          reversed_by?: string | null
          status?: Database["public"]["Enums"]["expense_status"]
          supplier_id?: string
          total_amount_minor?: number
          treasury_account_id?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "supplier_payments_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "supplier_payments_posted_journal_same_company"
            columns: ["company_id", "posted_journal_entry_id"]
            isOneToOne: false
            referencedRelation: "journal_entries"
            referencedColumns: ["company_id", "id"]
          },
          {
            foreignKeyName: "supplier_payments_reversal_journal_same_company"
            columns: ["company_id", "reversal_journal_entry_id"]
            isOneToOne: false
            referencedRelation: "journal_entries"
            referencedColumns: ["company_id", "id"]
          },
          {
            foreignKeyName: "supplier_payments_supplier_same_company"
            columns: ["company_id", "supplier_id"]
            isOneToOne: false
            referencedRelation: "parties"
            referencedColumns: ["company_id", "id"]
          },
          {
            foreignKeyName: "supplier_payments_treasury_same_company"
            columns: ["company_id", "treasury_account_id"]
            isOneToOne: false
            referencedRelation: "treasury_accounts"
            referencedColumns: ["company_id", "id"]
          },
        ]
      }
      treasury_accounts: {
        Row: {
          account_reference: string | null
          bank_name: string | null
          code: string
          company_id: string
          created_at: string
          created_by: string | null
          gl_account_id: string
          id: string
          name: string
          notes: string | null
          project_id: string | null
          status: Database["public"]["Enums"]["account_status"]
          type: Database["public"]["Enums"]["treasury_account_type"]
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          account_reference?: string | null
          bank_name?: string | null
          code: string
          company_id: string
          created_at?: string
          created_by?: string | null
          gl_account_id: string
          id?: string
          name: string
          notes?: string | null
          project_id?: string | null
          status?: Database["public"]["Enums"]["account_status"]
          type: Database["public"]["Enums"]["treasury_account_type"]
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          account_reference?: string | null
          bank_name?: string | null
          code?: string
          company_id?: string
          created_at?: string
          created_by?: string | null
          gl_account_id?: string
          id?: string
          name?: string
          notes?: string | null
          project_id?: string | null
          status?: Database["public"]["Enums"]["account_status"]
          type?: Database["public"]["Enums"]["treasury_account_type"]
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "treasury_accounts_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "treasury_gl_same_company"
            columns: ["company_id", "gl_account_id"]
            isOneToOne: false
            referencedRelation: "accounts"
            referencedColumns: ["company_id", "id"]
          },
          {
            foreignKeyName: "treasury_project_same_company"
            columns: ["company_id", "project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["company_id", "id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      can_access_project: {
        Args: { target_company_id: string; target_project_id: string }
        Returns: boolean
      }
      finalize_custody_settlement: {
        Args: {
          target_company_id: string
          target_custodian_id: string
          target_expected_total_minor: number
          target_expense_ids: string[]
          target_notes: string
          target_settlement_date: string
        }
        Returns: {
          custody_settlement_id: string
          settlement_reference: string
          total_expenses_minor: number
        }[]
      }
      has_active_project_assignment: {
        Args: { target_company_id: string; target_project_id: string }
        Returns: boolean
      }
      has_company_role: {
        Args: {
          required_role: Database["public"]["Enums"]["company_role"]
          target_company_id: string
        }
        Returns: boolean
      }
      has_permission: {
        Args: { required_permission: string; target_company_id: string }
        Returns: boolean
      }
      is_active_user: { Args: never; Returns: boolean }
      is_company_member: {
        Args: { target_company_id: string }
        Returns: boolean
      }
      post_custody_advance: {
        Args: {
          target_advance_date: string
          target_amount_minor: number
          target_company_id: string
          target_custodian_id: string
          target_external_reference: string
          target_idempotency_key: string
          target_notes: string
          target_payment_method: Database["public"]["Enums"]["payment_method"]
          target_project_id: string
          target_treasury_account_id: string
        }
        Returns: {
          advance_reference: string
          custody_advance_id: string
          journal_entry_id: string
          replayed: boolean
        }[]
      }
      post_custody_cash_return: {
        Args: {
          target_amount_minor: number
          target_company_id: string
          target_custodian_id: string
          target_external_reference: string
          target_idempotency_key: string
          target_notes: string
          target_payment_method: Database["public"]["Enums"]["payment_method"]
          target_return_date: string
          target_treasury_account_id: string
        }
        Returns: {
          custody_cash_return_id: string
          journal_entry_id: string
          replayed: boolean
          return_reference: string
        }[]
      }
      post_expense: {
        Args: {
          target_company_id: string
          target_description: string
          target_expense_category_id: string
          target_expense_date: string
          target_funding_mode: Database["public"]["Enums"]["expense_funding_mode"]
          target_has_tax_invoice: boolean
          target_idempotency_key: string
          target_invoice_number: string
          target_manual_vat_amount_minor: number
          target_net_amount_minor: number
          target_notes: string
          target_paid_by_party_id: string
          target_payment_method: Database["public"]["Enums"]["payment_method"]
          target_project_id: string
          target_supplier_id: string
          target_treasury_account_id: string
          target_vat_mode: Database["public"]["Enums"]["expense_vat_mode"]
        }
        Returns: {
          expense_id: string
          expense_reference: string
          journal_entry_id: string
          replayed: boolean
        }[]
      }
      post_subcontractor_advance: {
        Args: {
          target_advance_date: string
          target_amount_minor: number
          target_company_id: string
          target_external_reference: string
          target_idempotency_key: string
          target_notes: string
          target_payment_method: Database["public"]["Enums"]["payment_method"]
          target_subcontract_id: string
          target_treasury_account_id: string
        }
        Returns: {
          advance_reference: string
          journal_entry_id: string
          replayed: boolean
          subcontractor_advance_id: string
        }[]
      }
      post_supplier_payment: {
        Args: {
          target_allocations: Json
          target_company_id: string
          target_external_reference: string
          target_idempotency_key: string
          target_notes: string
          target_payment_date: string
          target_payment_method: Database["public"]["Enums"]["payment_method"]
          target_supplier_id: string
          target_total_amount_minor: number
          target_treasury_account_id: string
        }
        Returns: {
          journal_entry_id: string
          payment_reference: string
          replayed: boolean
          supplier_payment_id: string
        }[]
      }
      reverse_custody_advance: {
        Args: {
          target_company_id: string
          target_custody_advance_id: string
          target_idempotency_key: string
          target_reason: string
          target_reversal_date: string
        }
        Returns: {
          advance_reference: string
          custody_advance_id: string
          replayed: boolean
          reversal_journal_entry_id: string
        }[]
      }
      reverse_custody_cash_return: {
        Args: {
          target_company_id: string
          target_custody_cash_return_id: string
          target_idempotency_key: string
          target_reason: string
          target_reversal_date: string
        }
        Returns: {
          custody_cash_return_id: string
          replayed: boolean
          return_reference: string
          reversal_journal_entry_id: string
        }[]
      }
      reverse_expense: {
        Args: {
          target_company_id: string
          target_expense_id: string
          target_idempotency_key: string
          target_reason: string
          target_reversal_date: string
        }
        Returns: {
          expense_id: string
          expense_reference: string
          replayed: boolean
          reversal_journal_entry_id: string
        }[]
      }
      reverse_subcontractor_advance: {
        Args: {
          target_company_id: string
          target_idempotency_key: string
          target_reason: string
          target_reversal_date: string
          target_subcontractor_advance_id: string
        }
        Returns: {
          advance_reference: string
          replayed: boolean
          reversal_journal_entry_id: string
          subcontractor_advance_id: string
        }[]
      }
      reverse_supplier_payment: {
        Args: {
          target_company_id: string
          target_idempotency_key: string
          target_reason: string
          target_reversal_date: string
          target_supplier_payment_id: string
        }
        Returns: {
          payment_reference: string
          replayed: boolean
          reversal_journal_entry_id: string
          supplier_payment_id: string
        }[]
      }
    }
    Enums: {
      account_status: "ACTIVE" | "INACTIVE"
      account_type: "ASSET" | "LIABILITY" | "EQUITY" | "REVENUE" | "EXPENSE"
      app_locale: "en" | "ar"
      company_role:
        | "SYSTEM_ADMIN"
        | "ACCOUNTING_ADMIN"
        | "ACCOUNTANT"
        | "PROJECT_MANAGER"
        | "DATA_ENTRY"
        | "PROCUREMENT"
        | "MANAGEMENT_VIEWER"
      custody_settlement_status: "DRAFT" | "FINALIZED"
      expense_funding_mode:
        | "TREASURY"
        | "CUSTODIAN"
        | "OWNER"
        | "SUPPLIER_CREDIT"
      expense_status: "DRAFT" | "POSTED" | "REVERSED"
      expense_vat_mode: "ZERO" | "AUTO_5" | "MANUAL"
      party_type:
        | "OWNER"
        | "CUSTODIAN"
        | "SUPPLIER"
        | "EMPLOYEE"
        | "SUBCONTRACTOR"
        | "OTHER"
      payment_method: "CASH" | "BANK" | "TRANSFER" | "CHEQUE" | "OTHER"
      project_status: "PLANNING" | "ACTIVE" | "ON_HOLD" | "COMPLETED" | "CLOSED"
      subcontract_status: "ACTIVE" | "COMPLETED" | "CLOSED"
      system_account_key:
        | "INPUT_VAT"
        | "CUSTODY_ADVANCE"
        | "SUPPLIER_PAYABLE"
        | "OWNER_CURRENT"
        | "SUBCONTRACTOR_ADVANCE"
        | "SUBCONTRACTOR_PAYABLE"
        | "SUBCONTRACTOR_RETENTION_PAYABLE"
        | "PROJECT_COST"
        | "PROJECT_COST_SUBCONTRACTORS"
        | "COMPANY_EXPENSE"
      treasury_account_type:
        | "CASH"
        | "PETTY_CASH"
        | "BANK"
        | "PROJECT_CASH_BOX"
        | "PROJECT_BANK"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  graphql_public: {
    Enums: {},
  },
  public: {
    Enums: {
      account_status: ["ACTIVE", "INACTIVE"],
      account_type: ["ASSET", "LIABILITY", "EQUITY", "REVENUE", "EXPENSE"],
      app_locale: ["en", "ar"],
      company_role: [
        "SYSTEM_ADMIN",
        "ACCOUNTING_ADMIN",
        "ACCOUNTANT",
        "PROJECT_MANAGER",
        "DATA_ENTRY",
        "PROCUREMENT",
        "MANAGEMENT_VIEWER",
      ],
      custody_settlement_status: ["DRAFT", "FINALIZED"],
      expense_funding_mode: [
        "TREASURY",
        "CUSTODIAN",
        "OWNER",
        "SUPPLIER_CREDIT",
      ],
      expense_status: ["DRAFT", "POSTED", "REVERSED"],
      expense_vat_mode: ["ZERO", "AUTO_5", "MANUAL"],
      party_type: [
        "OWNER",
        "CUSTODIAN",
        "SUPPLIER",
        "EMPLOYEE",
        "SUBCONTRACTOR",
        "OTHER",
      ],
      payment_method: ["CASH", "BANK", "TRANSFER", "CHEQUE", "OTHER"],
      project_status: ["PLANNING", "ACTIVE", "ON_HOLD", "COMPLETED", "CLOSED"],
      subcontract_status: ["ACTIVE", "COMPLETED", "CLOSED"],
      system_account_key: [
        "INPUT_VAT",
        "CUSTODY_ADVANCE",
        "SUPPLIER_PAYABLE",
        "OWNER_CURRENT",
        "SUBCONTRACTOR_ADVANCE",
        "SUBCONTRACTOR_PAYABLE",
        "SUBCONTRACTOR_RETENTION_PAYABLE",
        "PROJECT_COST",
        "PROJECT_COST_SUBCONTRACTORS",
        "COMPANY_EXPENSE",
      ],
      treasury_account_type: [
        "CASH",
        "PETTY_CASH",
        "BANK",
        "PROJECT_CASH_BOX",
        "PROJECT_BANK",
      ],
    },
  },
} as const
