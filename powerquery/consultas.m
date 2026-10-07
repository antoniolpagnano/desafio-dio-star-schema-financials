// =============================================================================
//  DESAFIO DIO | STAR SCHEMA COM POWER BI - BASE FINANCIAL SAMPLE
//  Codigo M das seis consultas do Power Query
// =============================================================================
//  Autor...: Antonio Pagnano
//  GitHub..: https://github.com/antoniolpagnano
//
//  Para reproduzir: cada bloco abaixo vai numa consulta propria.
//  A primeira e criada por "Nova Fonte > Excel"; as cinco seguintes por
//  "Referencia" a partir da financials_origem (botao direito > Referencia).
//  Cole o bloco em Pagina Inicial > Editor Avancado.
// =============================================================================


// -----------------------------------------------------------------------------
//  1. financials_origem        700 linhas    CARGA DESABILITADA
// -----------------------------------------------------------------------------
//  Backup oculto que alimenta todas as demais consultas.
//  Alem da carga do arquivo, faz tres coisas que o resto do modelo herda:
//    - renomeia " Sales" para "Sales" (a coluna tem um espaco no arquivo
//      original, que obrigaria a escapar o nome em toda formula DAX);
//    - cria o SK_ID, indice sequencial que identifica cada linha de venda;
//    - cria o ID_Produto, chave de 0 a 5 (equivalente ao que a tela
//      "Coluna Condicional" gera).
//
//  Troque o caminho do arquivo pelo seu antes de usar.
// -----------------------------------------------------------------------------
let
    Fonte = Excel.Workbook(
        File.Contents("C:\Users\SEU_USUARIO\Downloads\Financial Sample.xlsx"), null, true),
    Planilha = Fonte{[Item="Sheet1", Kind="Sheet"]}[Data],
    Cabecalhos = Table.PromoteHeaders(Planilha, [PromoteAllScalars=true]),
    SalesSemEspaco = Table.RenameColumns(Cabecalhos, {{" Sales", "Sales"}}),
    Tipos = Table.TransformColumnTypes(SalesSemEspaco, {
        {"Segment", type text}, {"Country", type text}, {"Product", type text},
        {"Discount Band", type text}, {"Units Sold", type number},
        {"Manufacturing Price", Int64.Type}, {"Sale Price", Int64.Type},
        {"Gross Sales", type number}, {"Discounts", type number},
        {"Sales", type number}, {"COGS", type number}, {"Profit", type number},
        {"Date", type date}, {"Month Number", Int64.Type},
        {"Month Name", type text}, {"Year", Int64.Type}
    }),
    SK = Table.AddIndexColumn(Tipos, "SK_ID", 0, 1, Int64.Type),
    ID_Produto = Table.AddColumn(SK, "ID_Produto", each
        if [Product] = "Carretera" then 0
        else if [Product] = "Montana"  then 1
        else if [Product] = "Paseo"    then 2
        else if [Product] = "Velo"     then 3
        else if [Product] = "VTT"      then 4
        else if [Product] = "Amarilla" then 5
        else null, Int64.Type)
in
    ID_Produto


// -----------------------------------------------------------------------------
//  2. D_Produtos               6 linhas
// -----------------------------------------------------------------------------
//  Unica dimensao no sentido estrito: 6 linhas descritivas, uma por produto.
//  Criada com "Agrupar por" em modo avancado, com cinco agregacoes.
// -----------------------------------------------------------------------------
let
    Origem = financials_origem,
    Agrupado = Table.Group(
        Origem,
        {"ID_Produto", "Product"},
        {
            {"Média de Unidades Vendidas", each List.Average([Units Sold]), type number},
            {"Média do valor de vendas",   each List.Average([Sale Price]), type number},
            {"Mediana do valor de vendas", each List.Median([Sale Price]),  type number},
            {"Valor máximo de venda",      each List.Max([Sale Price]),     type number},
            {"Valor mínimo de venda",      each List.Min([Sale Price]),     type number}
        }
    ),
    Renomeado = Table.RenameColumns(Agrupado, {{"Product", "Produto"}}),
    Ordenado  = Table.Sort(Renomeado, {{"ID_Produto", Order.Ascending}})
in
    Ordenado


// -----------------------------------------------------------------------------
//  3. D_Produtos_Detalhes      698 linhas
// -----------------------------------------------------------------------------
//  Detalhes de preco e volume por produto. Como Units Sold e uma metrica de
//  linha, a granularidade fica proxima da fato mesmo apos remover duplicatas -
//  o que caracteriza esta tabela como um ramo de snowflake, nao uma dimensao.
// -----------------------------------------------------------------------------
let
    Origem = financials_origem,
    Selecionado = Table.SelectColumns(Origem,
        {"ID_Produto", "Discount Band", "Sale Price", "Units Sold", "Manufacturing Price"}),
    SemDuplicatas = Table.Distinct(Selecionado),
    Ordenado = Table.Sort(SemDuplicatas, {{"ID_Produto", Order.Ascending}})
in
    Ordenado


// -----------------------------------------------------------------------------
//  4. D_Descontos              653 linhas
// -----------------------------------------------------------------------------
//  Mesma observacao da anterior: Discounts e metrica, nao atributo.
//  A coluna "Discounts" e renomeada para "Discount" conforme o enunciado.
// -----------------------------------------------------------------------------
let
    Origem = financials_origem,
    Selecionado = Table.SelectColumns(Origem, {"ID_Produto", "Discounts", "Discount Band"}),
    SemDuplicatas = Table.Distinct(Selecionado),
    Renomeado = Table.RenameColumns(SemDuplicatas, {{"Discounts", "Discount"}}),
    Ordenado = Table.Sort(Renomeado, {{"ID_Produto", Order.Ascending}})
in
    Ordenado


// -----------------------------------------------------------------------------
//  5. D_Detalhes               700 linhas        relacao 1:1 com F_Vendas
// -----------------------------------------------------------------------------
//  O enunciado pede, com asterisco, "as informacoes que nao foram contempladas
//  nas demais tabelas dimensao". Conferindo coluna por coluna o que ja havia
//  sido alocado, restam exatamente Gross Sales e COGS.
//
//  Carrega o SK_ID porque se relaciona com a FATO (uma linha por venda), e nao
//  com a dimensao de produto.
// -----------------------------------------------------------------------------
let
    Origem = financials_origem,
    Selecionado = Table.SelectColumns(Origem, {"SK_ID", "ID_Produto", "Gross Sales", "COGS"}),
    Ordenado = Table.Sort(Selecionado, {{"SK_ID", Order.Ascending}})
in
    Ordenado


// -----------------------------------------------------------------------------
//  6. F_Vendas                 700 linhas        TABELA FATO
// -----------------------------------------------------------------------------
//  Grao: uma linha por venda registrada.
//  Carrega as duas chaves (SK_ID e ID_Produto), os atributos de recorte
//  (Segment, Country, Discount Band), a data e as metricas aditivas.
// -----------------------------------------------------------------------------
let
    Origem = financials_origem,
    Selecionado = Table.SelectColumns(Origem,
        {"SK_ID", "ID_Produto", "Product", "Units Sold", "Sale Price", "Discount Band",
         "Segment", "Country", "Sales", "Profit", "Date"}),
    Ordenado = Table.Sort(Selecionado, {{"SK_ID", Order.Ascending}})
in
    Ordenado
