
extension IF.Condition: Conditionable {

    // View `Conditionable` documentation
    public func evaluate<T>(with manager: HTMLRenderer.ContextManager<T>) throws -> Bool {
        return try condition.evaluate(with: manager)
    }

    // View `CompiledTemplate` documentation
    public func render<T>(with manager: HTMLRenderer.ContextManager<T>) throws -> String {
        return try localFormula.render(with: manager)
    }

    // View `BrewableFormula` documentation
    public func prerender(_ formula: HTMLRenderer.Formula) throws {
        try view.prerender(localFormula)
    }
}

/// This is a struct that should never exist in a template, and therefore will be used to evaluate if a `Condition`is dynamic or static
struct ConditionPrerenderTest {}

enum IFPrerenderErrors: Error {
    case dynamiclyEvaluatedCondition
}

extension IF: HTML {

    // View `CompiledTemplate` documentation
    public func render<T>(with manager: HTMLRenderer.ContextManager<T>) throws -> String {
        for condition in conditions {
            if try condition.evaluate(with: manager) {
                return try condition.render(with: manager)
            }
        }
        return ""
    }

    // View `BrewableFormula` documentation
    public func prerender(_ formula: HTMLRenderer.Formula) throws {
        var isStaticallyEvaluated = true
        for condition in conditions {
            condition.localFormula.calendar = formula.calendar
            condition.localFormula.timeZone = formula.timeZone

            do {
                guard isStaticallyEvaluated else {
                    throw IFPrerenderErrors.dynamiclyEvaluatedCondition
                }
                let testContext = HTMLRenderer.ContextManager<Void>(contexts: [:])
                if try condition.condition.evaluate(with: testContext) {
                    try condition.view.prerender(formula)
                    return // Returning as the first true condition should be the only one that is rendered
                }
            } catch {
                // If an error was thrown, then there is some missing context and therefore the whole condition should be evaluated at runtime
                isStaticallyEvaluated = false
                try condition.prerender(formula)
            }
        }
        if isStaticallyEvaluated == false {
            formula.add(mappable: self)
        }
    }

    /// Add an else if condition
    ///
    /// - Parameters:
    ///   - condition: The condition to be evaluated
    ///   - render: The view to render if true
    /// - Returns: returns a modified if statment
    public func elseIf(_ condition: Conditionable, @HTMLBuilder render: () -> HTML) -> IF {
        let ifCondition = Condition(condition: condition)
        ifCondition.view = render()
        return .init(conditions: conditions + [ifCondition])
    }

    /// Add an else if condition
    ///
    /// - Parameters:
    ///   - path: The path to evaluate
    ///   - render: The view to render if true
    /// - Returns: returns a modified if statment
    public func elseIf<B>(isNil path: TemplateValue<B?>, @HTMLBuilder render: () -> HTML) -> IF {
        let condition = Condition(condition: IsNullCondition<B>(path: path))
        condition.view = render()
        return .init(conditions: conditions + [condition])
    }

    /// Add an else if condition
    ///
    /// - Parameters:
    ///   - path: The path to evaluate
    ///   - render: The view to render if true
    /// - Returns: returns a modified if statment
    public func elseIf<Value>(isNotNil path: TemplateValue<Value?>, @HTMLBuilder render: () -> HTML) -> IF {
        let condition = Condition(condition: NotNullCondition<Value>(path: path))
        condition.view = render()
        return .init(conditions: conditions + [condition])
    }

    /// Add an else condition
    ///
    /// - Parameter render: The view to be rendered
    /// - Returns: A mappable object
    public func `else`(@HTMLBuilder render: () -> HTML) -> HTML {
        let trueCondition = Condition(condition: AlwaysTrueCondition())
        trueCondition.view = render()
        return IF(conditions: conditions + [trueCondition])
    }
}
