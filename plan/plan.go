//  Copyright (c) 2013 Couchbase, Inc.
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

// Plan is a description of a sequence of steps to produce a correct
// result for a query.

package plan

import (
	"encoding/json"

	"github.com/couchbaselabs/tuqtng/ast"
	"github.com/couchbaselabs/tuqtng/catalog"
)

type Plan struct {
	Root PlanElement `json:"root"`
}

type PlanChannel chan Plan

type PlanElement interface {
	Sources() []PlanElement
}

type Explain struct {
	Type  string      `json:"type"`
	Input PlanElement `json:"input"`
}

func NewExplain(input PlanElement) *Explain {
	return &Explain{
		Type:  "explain",
		Input: input,
	}
}

func (this *Explain) Sources() []PlanElement {
	return []PlanElement{}
}

type ScanRange struct {
	Low       catalog.LookupValue
	High      catalog.LookupValue
	Inclusion catalog.RangeInclusion
}

func (sr ScanRange) MarshalJSON() ([]byte, error) {
	r := map[string]interface{}{}

	low := make([]interface{}, len(sr.Low))
	for i, l := range sr.Low {
		low[i] = l.Value()
	}
	if len(low) > 0 {
		r["low"] = low
	}

	high := make([]interface{}, len(sr.High))
	for i, l := range sr.High {
		high[i] = l.Value()
	}
	if len(high) > 0 {
		r["high"] = high
	}

	switch sr.Inclusion {
	case catalog.Neither:
		r["inclusion"] = "neither"
	case catalog.Low:
		r["inclusion"] = "low"
	case catalog.High:
		r["inclusion"] = "high"
	case catalog.Both:
		r["inclusion"] = "both"
	}

	return json.Marshal(r)
}

type ScanRanges []*ScanRange

type Scan struct {
	Type      string     `json:"type"`
	ScanIndex string     `json:"index"`
	Bucket    string     `json:"bucket"`
	Pool      string     `json:"pool"`
	Ranges    ScanRanges `json:"ranges"`
}

func NewScan(pool string, bucket string, index string, ranges ScanRanges) *Scan {
	return &Scan{
		Type:      "scan",
		Pool:      pool,
		Bucket:    bucket,
		ScanIndex: index,
		Ranges:    ranges,
	}
}

func (this *Scan) Sources() []PlanElement {
	return []PlanElement{}
}

type Fetch struct {
	Type       string         `json:"type"`
	Input      PlanElement    `json:"input"`
	Bucket     string         `json:"bucket"`
	Pool       string         `json:"pool"`
	Projection ast.Expression `json:"projection"`
	As         string         `json:"as"`
}

func NewFetch(input PlanElement, pool string, bucket string, projection ast.Expression, as string) *Fetch {
	return &Fetch{
		Type:       "fetch",
		Input:      input,
		Pool:       pool,
		Bucket:     bucket,
		Projection: projection,
		As:         as,
	}
}

func (this *Fetch) Sources() []PlanElement {
	return []PlanElement{this.Input}
}

type Filter struct {
	Type  string         `json:"type"`
	Input PlanElement    `json:"input"`
	Expr  ast.Expression `json:"expr"`
}

func NewFilter(input PlanElement, expr ast.Expression) *Filter {
	return &Filter{
		Type:  "filter",
		Input: input,
		Expr:  expr,
	}
}

func (this *Filter) Sources() []PlanElement {
	return []PlanElement{this.Input}
}

type Order struct {
	Type            string                `json:"type"`
	Input           PlanElement           `json:"input"`
	Sort            []*ast.SortExpression `json:"sort"`
	ExplicitAliases []string              `json:"explicit_aliases"`
}

func NewOrder(input PlanElement, sort []*ast.SortExpression, explicitAliases []string) *Order {
	return &Order{
		Type:            "order",
		Input:           input,
		Sort:            sort,
		ExplicitAliases: explicitAliases,
	}
}

func (this *Order) Sources() []PlanElement {
	return []PlanElement{this.Input}
}

type Limit struct {
	Type  string      `json:"type"`
	Input PlanElement `json:"input"`
	Val   int         `json:"value"`
}

func NewLimit(input PlanElement, limit int) *Limit {
	return &Limit{
		Type:  "limit",
		Input: input,
		Val:   limit,
	}
}

func (this *Limit) Sources() []PlanElement {
	return []PlanElement{this.Input}
}

type Offset struct {
	Type  string      `json:"type"`
	Input PlanElement `json:"input"`
	Val   int         `json:"value"`
}

func NewOffset(input PlanElement, offset int) *Offset {
	return &Offset{
		Type:  "offset",
		Input: input,
		Val:   offset,
	}
}

func (this *Offset) Sources() []PlanElement {
	return []PlanElement{this.Input}
}

type Projector struct {
	Type         string                   `json:"type"`
	Input        PlanElement              `json:"input"`
	Result       ast.ResultExpressionList `json:"result"`
	ProjectEmpty bool                     `json:"-"`
}

func NewProjector(input PlanElement, result ast.ResultExpressionList, projectEmpty bool) *Projector {
	return &Projector{
		Type:         "projector",
		Input:        input,
		Result:       result,
		ProjectEmpty: projectEmpty,
	}
}

func (this *Projector) Sources() []PlanElement {
	return []PlanElement{this.Input}
}

type ProjectorInline struct {
	Type   string                `json:"type"`
	Input  PlanElement           `json:"input"`
	Result *ast.ResultExpression `json:"result"`
}

func NewProjectorInline(input PlanElement, result *ast.ResultExpression) *ProjectorInline {
	return &ProjectorInline{
		Type:   "projector-inline",
		Input:  input,
		Result: result,
	}
}

func (this *ProjectorInline) Sources() []PlanElement {
	return []PlanElement{this.Input}
}

type DocumentJoin struct {
	Type  string         `json:"type"`
	Input PlanElement    `json:"input"`
	Over  ast.Expression `json:"over"`
	As    string         `json:"as"`
}

func NewDocumentJoin(input PlanElement, over ast.Expression, as string) *DocumentJoin {
	return &DocumentJoin{
		Type:  "document-join",
		Input: input,
		Over:  over,
		As:    as,
	}
}

func (this *DocumentJoin) Sources() []PlanElement {
	return []PlanElement{this.Input}
}

type EliminateDuplicates struct {
	Type  string      `json:"type"`
	Input PlanElement `json:"input"`
}

func NewEliminateDuplicates(input PlanElement) *EliminateDuplicates {
	return &EliminateDuplicates{
		Type:  "eliminate-duplicates",
		Input: input,
	}
}

func (this *EliminateDuplicates) Sources() []PlanElement {
	return []PlanElement{this.Input}
}

type Grouper struct {
	Type       string             `json:"type"`
	Input      PlanElement        `json:"input"`
	Group      ast.ExpressionList `json:"group"`
	Aggregates ast.ExpressionList `json:"aggregates"`
}

func NewGroup(input PlanElement, group ast.ExpressionList, agg ast.ExpressionList) *Grouper {
	return &Grouper{
		Type:       "grouper",
		Input:      input,
		Group:      group,
		Aggregates: agg,
	}
}

func (this *Grouper) Sources() []PlanElement {
	return []PlanElement{this.Input}
}

type CreateIndex struct {
	Type      string             `json:"type"`
	Pool      string             `json:"pool"`
	Bucket    string             `json:"bucket"`
	Name      string             `json:"name"`
	IndexType string             `json:"index_type"`
	On        ast.ExpressionList `json:"on"`
}

func NewCreateIndex(pool string, bucket string, name string, index_type string, on ast.ExpressionList) *CreateIndex {
	return &CreateIndex{
		Type:      "create_index",
		Pool:      pool,
		Bucket:    bucket,
		Name:      name,
		IndexType: index_type,
		On:        on,
	}
}

func (this *CreateIndex) Sources() []PlanElement {
	return []PlanElement{}
}

type DropIndex struct {
	Type   string `json:"type"`
	Pool   string `json:"pool"`
	Bucket string `json:"bucket"`
	Name   string `json:"name"`
}

func NewDropIndex(pool string, bucket string, name string) *DropIndex {
	return &DropIndex{
		Type:   "drop_index",
		Pool:   pool,
		Bucket: bucket,
		Name:   name,
	}
}

func (this *DropIndex) Sources() []PlanElement {
	return []PlanElement{}
}
